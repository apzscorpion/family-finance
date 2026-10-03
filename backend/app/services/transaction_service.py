import json
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from app.models.transaction import Transaction, TransactionTransfer, TransactionSplit
from app.models.source import FinancialSource
from app.models.organization import OrganizationMember, RoleEnum
from app.services.audit_service import log_transaction_audit

def update_source_balance(db: Session, source_id: Optional[str], delta_cents: int):
    if not source_id:
        return
    source = db.query(FinancialSource).filter(FinancialSource.id == source_id).first()
    if source:
        source.current_balance_cents += delta_cents
        db.flush()

def create_transaction(
    db: Session,
    creator_id: str,
    target_user_id: str,
    amount_cents: int,
    direction: str,
    category: str,
    source_id: Optional[str] = None,
    organization_id: Optional[str] = None,
    description: Optional[str] = None,
    merchant_or_payee: Optional[str] = None,
    payment_method: str = "OTHER",
    date_time: Optional[datetime] = None,
    entry_origin: str = "MANUAL",
    verification_status: str = "CONFIRMED",
    notes: Optional[str] = None
) -> Transaction:
    if amount_cents <= 0:
        raise HTTPException(status_code=400, detail="Transaction amount must be greater than zero")

    # Access control & target member validation
    if creator_id != target_user_id:
        if not organization_id:
            raise HTTPException(status_code=403, detail="Cannot create transaction for another user outside an organization")
        
        # Check creator member role in org
        creator_member = db.query(OrganizationMember).filter(
            OrganizationMember.organization_id == organization_id,
            OrganizationMember.user_id == creator_id,
            OrganizationMember.is_active == "ACTIVE"
        ).first()

        if not creator_member:
            raise HTTPException(status_code=403, detail="Creator is not an active organization member")

        # Non-owners must use Proposal Workflow for adding transactions on behalf of another member
        if creator_member.role != RoleEnum.OWNER.value:
            raise HTTPException(status_code=403, detail="Only Organization Owner can create direct transactions for other members. Members must submit a proposal.")

    # Source validation
    if source_id:
        source = db.query(FinancialSource).filter(FinancialSource.id == source_id).first()
        if not source:
            raise HTTPException(status_code=404, detail="Financial source not found")
        if source.owner_id != target_user_id:
            raise HTTPException(status_code=400, detail="Financial source does not belong to target user")

    txn = Transaction(
        owner_id=target_user_id,
        organization_id=organization_id,
        source_id=source_id,
        amount_cents=amount_cents,
        direction=direction,
        category=category,
        description=description,
        merchant_or_payee=merchant_or_payee,
        payment_method=payment_method,
        date_time=date_time or datetime.utcnow(),
        entry_origin=entry_origin,
        verification_status=verification_status,
        created_by_id=creator_id,
        last_modified_by_id=creator_id,
        notes=notes,
        version=1
    )
    db.add(txn)
    db.flush()

    # Update balance if confirmed
    if verification_status == "CONFIRMED":
        if direction in ["INCOME", "REFUND", "LOAN_DISBURSEMENT", "TRANSFER_IN"]:
            update_source_balance(db, source_id, amount_cents)
        elif direction in ["EXPENSE", "TRANSFER_OUT"]:
            update_source_balance(db, source_id, -amount_cents)

    # Audit Logging
    action = "OWNER_OVERRIDE" if creator_id != target_user_id else "CREATED"
    log_transaction_audit(
        db=db,
        transaction_id=txn.id,
        actor_user_id=creator_id,
        target_user_id=target_user_id,
        action_type=action,
        organization_id=organization_id,
        snapshot_after={
            "amount_cents": amount_cents,
            "direction": direction,
            "category": category,
            "source_id": source_id
        }
    )

    db.commit()
    db.refresh(txn)
    return txn

def update_transaction_direct(
    db: Session,
    txn_id: str,
    editor_id: str,
    updates: Dict[str, Any],
    expected_version: Optional[int] = None
) -> Transaction:
    txn = db.query(Transaction).filter(Transaction.id == txn_id, Transaction.is_deleted == False).first()
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")

    # Optimistic locking check
    if expected_version is not None and txn.version != expected_version:
        raise HTTPException(status_code=409, detail=f"Transaction conflict: Version has changed from {expected_version} to {txn.version}")

    # Check permission
    if editor_id != txn.owner_id:
        if not txn.organization_id:
            raise HTTPException(status_code=403, detail="Not authorized to edit transaction")
        
        editor_member = db.query(OrganizationMember).filter(
            OrganizationMember.organization_id == txn.organization_id,
            OrganizationMember.user_id == editor_id,
            OrganizationMember.is_active == "ACTIVE"
        ).first()

        if not editor_member or editor_member.role != RoleEnum.OWNER.value:
            raise HTTPException(status_code=403, detail="Only the owner can directly edit another member's transaction. Use proposal workflow.")

    before_snapshot = {
        "amount_cents": txn.amount_cents,
        "direction": txn.direction,
        "category": txn.category,
        "source_id": txn.source_id,
        "version": txn.version
    }

    # Revert balance effect of previous state if confirmed
    if txn.verification_status == "CONFIRMED":
        if txn.direction in ["INCOME", "REFUND", "LOAN_DISBURSEMENT", "TRANSFER_IN"]:
            update_source_balance(db, txn.source_id, -txn.amount_cents)
        elif txn.direction in ["EXPENSE", "TRANSFER_OUT"]:
            update_source_balance(db, txn.source_id, txn.amount_cents)

    # Apply updates
    if "amount_cents" in updates and updates["amount_cents"] is not None:
        txn.amount_cents = updates["amount_cents"]
    if "category" in updates and updates["category"] is not None:
        txn.category = updates["category"]
    if "description" in updates and updates["description"] is not None:
        txn.description = updates["description"]
    if "merchant_or_payee" in updates and updates["merchant_or_payee"] is not None:
        txn.merchant_or_payee = updates["merchant_or_payee"]
    if "source_id" in updates and updates["source_id"] is not None:
        txn.source_id = updates["source_id"]

    txn.version += 1
    txn.last_modified_by_id = editor_id

    # Apply balance effect of new state if confirmed
    if txn.verification_status == "CONFIRMED":
        if txn.direction in ["INCOME", "REFUND", "LOAN_DISBURSEMENT", "TRANSFER_IN"]:
            update_source_balance(db, txn.source_id, txn.amount_cents)
        elif txn.direction in ["EXPENSE", "TRANSFER_OUT"]:
            update_source_balance(db, txn.source_id, -txn.amount_cents)

    action = "OWNER_OVERRIDE" if editor_id != txn.owner_id else "UPDATED"
    log_transaction_audit(
        db=db,
        transaction_id=txn.id,
        actor_user_id=editor_id,
        target_user_id=txn.owner_id,
        action_type=action,
        organization_id=txn.organization_id,
        snapshot_before=before_snapshot,
        snapshot_after={
            "amount_cents": txn.amount_cents,
            "direction": txn.direction,
            "category": txn.category,
            "source_id": txn.source_id,
            "version": txn.version
        }
    )

    db.commit()
    db.refresh(txn)
    return txn

def create_member_transfer(
    db: Session,
    sender_user_id: str,
    from_source_id: str,
    receiver_user_id: str,
    to_source_id: str,
    amount_cents: int,
    description: Optional[str] = None
) -> TransactionTransfer:
    if amount_cents <= 0:
        raise HTTPException(status_code=400, detail="Transfer amount must be greater than zero")

    transfer_group_id = str(uuid.uuid4())

    debit_txn = create_transaction(
        db=db,
        creator_id=sender_user_id,
        target_user_id=sender_user_id,
        amount_cents=amount_cents,
        direction="TRANSFER_OUT",
        category="Transfer Out",
        source_id=from_source_id,
        description=description or f"Transfer to User {receiver_user_id}"
    )

    credit_txn = create_transaction(
        db=db,
        creator_id=receiver_user_id,
        target_user_id=receiver_user_id,
        amount_cents=amount_cents,
        direction="TRANSFER_IN",
        category="Transfer In",
        source_id=to_source_id,
        description=description or f"Transfer from User {sender_user_id}"
    )

    transfer = TransactionTransfer(
        transfer_group_id=transfer_group_id,
        debit_transaction_id=debit_txn.id,
        credit_transaction_id=credit_txn.id,
        from_user_id=sender_user_id,
        to_user_id=receiver_user_id,
        status="CONFIRMED"
    )
    db.add(transfer)
    db.commit()
    db.refresh(transfer)
    return transfer

def create_split_expense(
    db: Session,
    payer_user_id: str,
    payer_source_id: str,
    total_amount_cents: int,
    category: str,
    description: str,
    splits: List[Dict[str, Any]],
    organization_id: Optional[str] = None
) -> Transaction:
    # Verify split amounts equal total expense
    split_sum = sum(s["split_amount_cents"] for s in splits)
    if split_sum != total_amount_cents:
        raise HTTPException(
            status_code=400,
            detail=f"Sum of split amounts ({split_sum} paisa) does not equal total expense ({total_amount_cents} paisa)"
        )

    # Create main expense for payer
    main_txn = create_transaction(
        db=db,
        creator_id=payer_user_id,
        target_user_id=payer_user_id,
        amount_cents=total_amount_cents,
        direction="EXPENSE",
        category=category,
        source_id=payer_source_id,
        organization_id=organization_id,
        description=description
    )

    for item in splits:
        split_rec = TransactionSplit(
            transaction_id=main_txn.id,
            beneficiary_user_id=item["beneficiary_user_id"],
            split_amount_cents=item["split_amount_cents"],
            notes=item.get("notes")
        )
        db.add(split_rec)

    db.commit()
    return main_txn
