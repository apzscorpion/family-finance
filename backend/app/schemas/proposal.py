from pydantic import BaseModel
from typing import Optional, Any, Dict
from datetime import datetime

class ProposalCreate(BaseModel):
    target_transaction_id: Optional[str] = None
    target_user_id: str
    proposal_type: str # ADDITION, EDIT, DELETION
    proposed_data: Dict[str, Any]
    target_version: Optional[int] = None
    reason: Optional[str] = None

class ProposalResponse(BaseModel):
    id: str
    target_transaction_id: Optional[str] = None
    target_user_id: str
    proposer_id: str
    proposal_type: str
    proposed_data: Dict[str, Any]
    original_data: Optional[Dict[str, Any]] = None
    target_version: Optional[int] = None
    reason: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class DecisionRequest(BaseModel):
    decision: str # APPROVED, REJECTED
    rejection_reason: Optional[str] = None
