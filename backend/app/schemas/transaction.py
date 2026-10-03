from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class TransactionCreate(BaseModel):
    owner_id: Optional[str] = None # Defaults to active user or specified member if authorized
    organization_id: Optional[str] = None
    source_id: Optional[str] = None
    amount_cents: int = Field(..., gt=0)
    currency: str = "INR"
    direction: str # INCOME, EXPENSE, TRANSFER_IN, TRANSFER_OUT, REFUND, LOAN_DISBURSEMENT
    category: str = "Unclassified"
    description: Optional[str] = None
    merchant_or_payee: Optional[str] = None
    payment_method: str = "OTHER" # CASH, UPI, BANK_TRANSFER, CARD
    date_time: Optional[datetime] = None
    entry_origin: str = "MANUAL"
    notes: Optional[str] = None

class TransactionUpdate(BaseModel):
    source_id: Optional[str] = None
    amount_cents: Optional[int] = None
    category: Optional[str] = None
    description: Optional[str] = None
    merchant_or_payee: Optional[str] = None
    payment_method: Optional[str] = None
    date_time: Optional[datetime] = None
    notes: Optional[str] = None
    expected_version: Optional[int] = None # For optimistic locking check

class TransactionResponse(BaseModel):
    id: str
    owner_id: str
    organization_id: Optional[str] = None
    source_id: Optional[str] = None
    amount_cents: int
    currency: str
    direction: str
    category: str
    description: Optional[str] = None
    merchant_or_payee: Optional[str] = None
    payment_method: str
    date_time: datetime
    entry_origin: str
    verification_status: str
    created_by_id: str
    last_modified_by_id: str
    notes: Optional[str] = None
    version: int
    is_deleted: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class TransferCreate(BaseModel):
    from_source_id: str
    to_user_id: str
    to_source_id: str
    amount_cents: int = Field(..., gt=0)
    description: Optional[str] = None

class SplitItem(BaseModel):
    beneficiary_user_id: str
    split_amount_cents: int

class SplitExpenseCreate(BaseModel):
    payer_source_id: str
    total_amount_cents: int = Field(..., gt=0)
    category: str
    description: str
    splits: List[SplitItem]
