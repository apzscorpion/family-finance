import json
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.proposal import ProposalCreate, ProposalResponse, DecisionRequest
from app.services import proposal_service
from app.api.deps import get_current_user
from app.models.user import User
from app.models.proposal import TransactionProposal

router = APIRouter(prefix="/approvals", tags=["Approvals"])

@router.post("/propose", response_model=ProposalResponse, status_code=status.HTTP_201_CREATED)
def propose_change(payload: ProposalCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    prop = proposal_service.create_proposal(
        db=db,
        proposer_id=current_user.id,
        target_user_id=payload.target_user_id,
        proposal_type=payload.proposal_type,
        proposed_data=payload.proposed_data,
        target_transaction_id=payload.target_transaction_id,
        reason=payload.reason
    )
    return ProposalResponse(
        id=prop.id,
        target_transaction_id=prop.target_transaction_id,
        target_user_id=prop.target_user_id,
        proposer_id=prop.proposer_id,
        proposal_type=prop.proposal_type,
        proposed_data=json.loads(prop.proposed_data),
        original_data=json.loads(prop.original_data) if prop.original_data else None,
        target_version=prop.target_version,
        reason=prop.reason,
        status=prop.status,
        created_at=prop.created_at,
        updated_at=prop.updated_at
    )

@router.get("/inbox", response_model=List[ProposalResponse])
def get_approval_inbox(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Returns proposals targeting current user that are PENDING
    proposals = db.query(TransactionProposal).filter(
        TransactionProposal.target_user_id == current_user.id
    ).order_by(TransactionProposal.created_at.desc()).all()

    results = []
    for prop in proposals:
        results.append(ProposalResponse(
            id=prop.id,
            target_transaction_id=prop.target_transaction_id,
            target_user_id=prop.target_user_id,
            proposer_id=prop.proposer_id,
            proposal_type=prop.proposal_type,
            proposed_data=json.loads(prop.proposed_data),
            original_data=json.loads(prop.original_data) if prop.original_data else None,
            target_version=prop.target_version,
            reason=prop.reason,
            status=prop.status,
            created_at=prop.created_at,
            updated_at=prop.updated_at
        ))
    return results

@router.post("/{proposal_id}/decide", response_model=ProposalResponse)
def decide_proposal(proposal_id: str, payload: DecisionRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    prop = proposal_service.decide_proposal(
        db=db,
        proposal_id=proposal_id,
        reviewer_id=current_user.id,
        decision=payload.decision,
        rejection_reason=payload.rejection_reason
    )
    return ProposalResponse(
        id=prop.id,
        target_transaction_id=prop.target_transaction_id,
        target_user_id=prop.target_user_id,
        proposer_id=prop.proposer_id,
        proposal_type=prop.proposal_type,
        proposed_data=json.loads(prop.proposed_data),
        original_data=json.loads(prop.original_data) if prop.original_data else None,
        target_version=prop.target_version,
        reason=prop.reason,
        status=prop.status,
        created_at=prop.created_at,
        updated_at=prop.updated_at
    )
