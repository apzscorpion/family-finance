from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class SMSIngestRequest(BaseModel):
    raw_sender: str
    raw_message: str
    received_at: Optional[datetime] = None

class SMSIngestResponse(BaseModel):
    id: str
    raw_sender: str
    parsed_amount_cents: Optional[int] = None
    parsed_direction: Optional[str] = None
    parsed_merchant: Optional[str] = None
    parsed_ref_id: Optional[str] = None
    parsed_payment_method: str = "UPI"
    confidence_score: float
    parsing_status: str # AUTO_CONFIRMED, NEEDS_REVIEW, IGNORED, DUPLICATE
    resulting_transaction_id: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class SMSReviewAction(BaseModel):
    action: str # CONFIRM, REJECT, EDIT
    source_id: Optional[str] = None
    category: Optional[str] = "Unclassified"
    amount_cents: Optional[int] = None
    merchant_or_payee: Optional[str] = None
