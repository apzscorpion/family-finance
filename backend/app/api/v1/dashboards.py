from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, Dict, Any, List
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.transaction import Transaction
from app.models.source import FinancialSource
from app.models.organization import OrganizationMember, RoleEnum
from app.models.proposal import TransactionProposal

router = APIRouter(prefix="/dashboards", tags=["Dashboards & Reports"])

@router.get("/personal")
def get_personal_dashboard(
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    query = db.query(Transaction).filter(
        Transaction.owner_id == current_user.id,
        Transaction.is_deleted == False,
        Transaction.verification_status == "CONFIRMED"
    )

    if start_date:
        query = query.filter(Transaction.date_time >= start_date)
    if end_date:
        query = query.filter(Transaction.date_time <= end_date)

    transactions = query.all()

    # Accurate financial totals (in minor units / paisa)
    income_earned_cents = sum(t.amount_cents for t in transactions if t.direction == "INCOME")
    expenses_cents = sum(t.amount_cents for t in transactions if t.direction == "EXPENSE")
    refunds_cents = sum(t.amount_cents for t in transactions if t.direction == "REFUND")
    loan_disbursements_cents = sum(t.amount_cents for t in transactions if t.direction == "LOAN_DISBURSEMENT")
    transfer_in_cents = sum(t.amount_cents for t in transactions if t.direction == "TRANSFER_IN")
    transfer_out_cents = sum(t.amount_cents for t in transactions if t.direction == "TRANSFER_OUT")

    net_cash_flow_cents = (income_earned_cents + refunds_cents) - expenses_cents

    # Tracked balances
    sources = db.query(FinancialSource).filter(
        FinancialSource.owner_id == current_user.id,
        FinancialSource.is_active == True
    ).all()
    total_tracked_balance_cents = sum(s.current_balance_cents for s in sources)

    # Category breakdown for expenses
    category_totals = {}
    for t in transactions:
        if t.direction == "EXPENSE":
            category_totals[t.category] = category_totals.get(t.category, 0) + t.amount_cents

    # Pending approvals count
    pending_approvals_count = db.query(func.count(TransactionProposal.id)).filter(
        TransactionProposal.target_user_id == current_user.id,
        TransactionProposal.status == "PENDING"
    ).scalar() or 0

    return {
        "user_id": current_user.id,
        "period": {"start": start_date, "end": end_date},
        "income_earned_cents": income_earned_cents,
        "expenses_cents": expenses_cents,
        "refunds_cents": refunds_cents,
        "loan_disbursements_cents": loan_disbursements_cents,
        "transfer_in_cents": transfer_in_cents,
        "transfer_out_cents": transfer_out_cents,
        "net_cash_flow_cents": net_cash_flow_cents,
        "total_tracked_balance_cents": total_tracked_balance_cents,
        "category_spending_cents": category_totals,
        "pending_approvals_count": pending_approvals_count
    }

@router.get("/organization/{org_id}")
def get_organization_dashboard(
    org_id: str,
    target_member_user_id: Optional[str] = None, # Account switcher filter
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    member = db.query(OrganizationMember).filter(
        OrganizationMember.organization_id == org_id,
        OrganizationMember.user_id == current_user.id,
        OrganizationMember.is_active == "ACTIVE"
    ).first()

    if not member:
        raise HTTPException(status_code=403, detail="Not an active member of this organization")

    query = db.query(Transaction).filter(
        Transaction.organization_id == org_id,
        Transaction.is_deleted == False,
        Transaction.verification_status == "CONFIRMED"
    )

    if target_member_user_id:
        if member.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value] and target_member_user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorized to filter dashboard by specific member view")
        query = query.filter(Transaction.owner_id == target_member_user_id)

    if start_date:
        query = query.filter(Transaction.date_time >= start_date)
    if end_date:
        query = query.filter(Transaction.date_time <= end_date)

    transactions = query.all()

    income_earned_cents = sum(t.amount_cents for t in transactions if t.direction == "INCOME")
    expenses_cents = sum(t.amount_cents for t in transactions if t.direction == "EXPENSE")

    # Member-wise spending breakdown
    member_spending = {}
    member_income = {}
    for t in transactions:
        if t.direction == "EXPENSE":
            member_spending[t.owner_id] = member_spending.get(t.owner_id, 0) + t.amount_cents
        elif t.direction == "INCOME":
            member_income[t.owner_id] = member_income.get(t.owner_id, 0) + t.amount_cents

    return {
        "organization_id": org_id,
        "view_context_user_id": target_member_user_id or "ALL",
        "total_confirmed_income_cents": income_earned_cents,
        "total_confirmed_expenses_cents": expenses_cents,
        "net_cash_flow_cents": income_earned_cents - expenses_cents,
        "member_spending_cents": member_spending,
        "member_income_cents": member_income
    }
