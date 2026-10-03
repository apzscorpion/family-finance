from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    type: str = "EXPENSE" # EXPENSE, INCOME
    icon: str = "category"
    organization_id: Optional[str] = None

class CategoryResponse(BaseModel):
    id: str
    name: str
    type: str
    icon: str
    is_custom: bool
    created_at: datetime

    class Config:
        from_attributes = True

class BudgetCreate(BaseModel):
    category_id: Optional[str] = None
    organization_id: Optional[str] = None
    period: str = "MONTHLY"
    target_amount_cents: int = Field(..., gt=0)
    alert_threshold_percentage: float = 80.0

class BudgetResponse(BaseModel):
    id: str
    category_id: Optional[str] = None
    organization_id: Optional[str] = None
    period: str
    target_amount_cents: int
    alert_threshold_percentage: float
    current_spent_cents: int = 0
    created_at: datetime

    class Config:
        from_attributes = True
