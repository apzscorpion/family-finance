import json
from datetime import datetime
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.proposal import TransactionProposal, ApprovalDecision
from app.models.transaction import Transaction
from app.services.transaction_service import create_transaction, update_transaction_direct
from app.services.audit_service import log_transaction_audit

def create_proposal(
    db: Session,
    proposer_id: str,
    target_user_id: str,
    proposal_type: str, # ADDITION, EDIT, DELETION
    proposed_data: Dict[str, Any],
    target_transaction_id: Optional[str] = None,
    reason: Optional[str] = None
) -> TransactionProposal:
    if proposer_id == target_user_id:
        raise HTTPException(status_code=400, detail="Cannot create proposal for yourself. Apply changes directly.")

    original_data = None
    target_version = None

    if proposal_type in ["EDIT", "DELETION"]:
        if not target_transaction_id:
            raise HTTPException(status_code=400, detail="Target transaction ID required for edit/deletion proposals")
        
        target_txn = db.query(Transaction).filter(Transaction.id == target_transaction_id).first()
        if not target_txn:
            raise HTTPException(status_code=404, detail="Target transaction not found")
        if target_txn.owner_id != target_user_id:
            raise HTTPException(status_code=400, detail="Target transaction does not belong to target user")

        original_data = {
            "amount_cents": target_txn.amount_cents,
            "category": target_txn.category,
            "description": target_txn.description,
            "merchant_or_payee": target_txn.merchant_or_payee,
            "source_id": target_txn.source_id,
            "version": target_txn.version
        }
        target_version = target_txn.version

    proposal = TransactionProposal(
        target_transaction_id=target_transaction_id,
        target_user_id=target_user_id,
        proposer_id=proposer_id,
        proposal_type=proposal_type,
        proposed_data=json.dumps(proposed_data),
        original_data=json.dumps(original_data) if original_data else None,
        target_version=target_version,
        reason=reason,
        status="PENDING"
    )
    db.add(proposal)
    db.flush()

    log_transaction_audit(
        db=db,
        transaction_id=target_transaction_id or proposal.id,
        actor_user_id=proposer_id,
        target_user_id=target_user_id,
        action_type="PROPOSED",
        snapshot_after=proposed_data
    )

    db.commit()
    db.refresh(proposal)
    return proposal

def decide_proposal(
    db: Session,
    proposal_id: str,
    reviewer_id: str,
    decision: str, # APPROVED, REJECTED
    rejection_reason: Optional[str] = None
) -> TransactionProposal:
    proposal = db.query(TransactionProposal).filter(TransactionProposal.id == proposal_id).first()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    if proposal.status != "PENDING":
        raise HTTPException(status_code=400, detail=f"Proposal is already {proposal.status.lower()}")

    # Rule: Proposer MUST NOT approve their own proposal on behalf of target user
    if reviewer_id == proposal.proposer_id:
        raise HTTPException(status_code=403, detail="Proposer cannot approve or reject their own proposal")

    # Rule: Only target user or authorized reviewer can decide proposal
    if reviewer_id != proposal.target_user_id:
        raise HTTPException(status_code=403, detail="Only the target financial owner can decide on this proposal")

    # Record decision
    app_decision = ApprovalDecision(
        proposal_id=proposal.id,
        reviewer_id=reviewer_id,
        decision=decision,
        rejection_reason=rejection_reason
    )
    db.add(app_decision)

    if decision == "REJECTED":
        proposal.status = "REJECTED"
        log_transaction_audit(
            db=db,
            transaction_id=proposal.target_transaction_id or proposal.id,
            actor_user_id=reviewer_id,
            target_user_id=proposal.target_user_id,
            action_type="REJECTED"
        )
        db.commit()
        return proposal

    # If APPROVED: Apply proposal
    parsed_proposed_data = json.loads(proposal.proposed_data)

    if proposal.proposal_type == "ADDITION":
        # When approved by target user, creation creator_id is target_user_id (approved by financial owner)
        new_txn = create_transaction(
            db=db,
            creator_id=proposal.target_user_id,
            target_user_id=proposal.target_user_id,
            amount_cents=parsed_proposed_data["amount_cents"],
            direction=parsed_proposed_data.get("direction", "EXPENSE"),
            category=parsed_proposed_data.get("category", "Unclassified"),
            source_id=parsed_proposed_data.get("source_id"),
            organization_id=parsed_proposed_data.get("organization_id"),
            description=parsed_proposed_data.get("description"),
            merchant_or_payee=parsed_proposed_data.get("merchant_or_payee"),
            payment_method=parsed_proposed_data.get("payment_method", "OTHER"),
            entry_origin="MANUAL",
            verification_status="CONFIRMED"
        )
        proposal.target_transaction_id = new_txn.id

    elif proposal.proposal_type == "EDIT":
        # Check stale proposal: verify version match
        target_txn = db.query(Transaction).filter(Transaction.id == proposal.target_transaction_id).first()
        if not target_txn:
            proposal.status = "CONFLICT"
            db.commit()
            raise HTTPException(status_code=400, detail="Target transaction missing")

        if target_txn.version != proposal.target_version:
            proposal.status = "CONFLICT"
            db.commit()
            raise HTTPException(
                status_code=409,
                detail=f"Stale edit proposal rejected: Transaction version changed from {proposal.target_version} to {target_txn.version}"
            )

        update_transaction_direct(
            db=db,
            txn_id=target_txn.id,
            editor_id=proposal.target_user_id,
            updates=parsed_proposed_data,
            expected_version=proposal.target_version
        )

    elif proposal.proposal_type == "DELETION":
        target_txn = db.query(Transaction).filter(Transaction.id == proposal.target_transaction_id).first()
        if target_txn:
            target_txn.is_deleted = True
            target_txn.verification_status = "VOIDED"
            db.flush()

    proposal.status = "APPROVED"
    log_transaction_audit(
        db=db,
        transaction_id=proposal.target_transaction_id or proposal.id,
        actor_user_id=reviewer_id,
        target_user_id=proposal.target_user_id,
        action_type="APPROVED"
    )

    db.commit()
    db.refresh(proposal)
    return proposal
