from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class SourceCreate(BaseModel):
    source_type: str # SALARY, BUSINESS, LOAN, POCKET_MONEY, GIFT, SAVINGS, RENTAL, CUSTOM
    display_name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    opening_balance_cents: int = 0
    currency: str = "INR"
    organization_id: Optional[str] = None
    business_name: Optional[str] = None
    business_description: Optional[str] = None
    loan_reference: Optional[str] = None
    loan_details: Optional[str] = None

class SourceUpdate(BaseModel):
    display_name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None
    business_name: Optional[str] = None
    business_description: Optional[str] = None
    loan_reference: Optional[str] = None
    loan_details: Optional[str] = None

class SourceResponse(BaseModel):
    id: str
    owner_id: str
    organization_id: Optional[str] = None
    source_type: str
    display_name: str
    description: Optional[str] = None
    opening_balance_cents: int
    current_balance_cents: int
    currency: str
    is_active: bool
    business_name: Optional[str] = None
    loan_reference: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
