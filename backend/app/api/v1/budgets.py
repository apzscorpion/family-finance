from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.budget import BudgetCreate, BudgetResponse, CategoryCreate, CategoryResponse
from app.models.budget import Budget, Category
from app.api.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/budgets", tags=["Budgets & Categories"])

@router.post("/categories", response_model=CategoryResponse)
def create_category(payload: CategoryCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cat = Category(
        user_id=current_user.id,
        organization_id=payload.organization_id,
        name=payload.name,
        type=payload.type,
        icon=payload.icon,
        is_custom=True
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat

@router.get("/categories", response_model=List[CategoryResponse])
def list_categories(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Category).all()

@router.post("", response_model=BudgetResponse)
def create_budget(payload: BudgetCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    budget = Budget(
        user_id=current_user.id,
        organization_id=payload.organization_id,
        category_id=payload.category_id,
        period=payload.period,
        target_amount_cents=payload.target_amount_cents,
        alert_threshold_percentage=payload.alert_threshold_percentage
    )
    db.add(budget)
    db.commit()
    db.refresh(budget)
    return budget
