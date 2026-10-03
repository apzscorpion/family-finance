from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.transaction import (
    TransactionCreate, TransactionUpdate, TransactionResponse,
    TransferCreate, SplitExpenseCreate
)
from app.services import transaction_service
from app.api.deps import get_current_user
from app.models.user import User
from app.models.transaction import Transaction
from app.models.organization import OrganizationMember, RoleEnum

router = APIRouter(prefix="/transactions", tags=["Transactions"])

@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(payload: TransactionCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    target_user_id = payload.owner_id or current_user.id
    txn = transaction_service.create_transaction(
        db=db,
        creator_id=current_user.id,
        target_user_id=target_user_id,
        amount_cents=payload.amount_cents,
        direction=payload.direction,
        category=payload.category,
        source_id=payload.source_id,
        organization_id=payload.organization_id,
        description=payload.description,
        merchant_or_payee=payload.merchant_or_payee,
        payment_method=payload.payment_method,
        date_time=payload.date_time,
        entry_origin=payload.entry_origin,
        notes=payload.notes
    )
    return txn

@router.get("", response_model=List[TransactionResponse])
def list_transactions(
    target_user_id: Optional[str] = None,
    org_id: Optional[str] = None,
    category: Optional[str] = None,
    direction: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    query = db.query(Transaction).filter(Transaction.is_deleted == False)

    if target_user_id and target_user_id != current_user.id:
        if not org_id:
            raise HTTPException(status_code=403, detail="Must provide org_id for member switching view")
        
        req_member = db.query(OrganizationMember).filter(
            OrganizationMember.organization_id == org_id,
            OrganizationMember.user_id == current_user.id,
            OrganizationMember.is_active == "ACTIVE"
        ).first()

        if not req_member or req_member.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
            raise HTTPException(status_code=403, detail="Not authorized to view other member's transactions")

        query = query.filter(Transaction.owner_id == target_user_id)
    elif not org_id:
        query = query.filter(Transaction.owner_id == current_user.id)

    if org_id:
        query = query.filter(Transaction.organization_id == org_id)
    if category:
        query = query.filter(Transaction.category == category)
    if direction:
        query = query.filter(Transaction.direction == direction)
    if start_date:
        query = query.filter(Transaction.date_time >= start_date)
    if end_date:
        query = query.filter(Transaction.date_time <= end_date)

    return query.order_by(Transaction.date_time.desc()).all()

@router.put("/{txn_id}", response_model=TransactionResponse)
def update_transaction(txn_id: str, payload: TransactionUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    updates = payload.dict(exclude_unset=True)
    expected_version = updates.pop("expected_version", None)
    return transaction_service.update_transaction_direct(
        db=db,
        txn_id=txn_id,
        editor_id=current_user.id,
        updates=updates,
        expected_version=expected_version
    )

@router.post("/transfer")
def transfer_funds(payload: TransferCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return transaction_service.create_member_transfer(
        db=db,
        sender_user_id=current_user.id,
        from_source_id=payload.from_source_id,
        receiver_user_id=payload.to_user_id,
        to_source_id=payload.to_source_id,
        amount_cents=payload.amount_cents,
        description=payload.description
    )

@router.post("/split", response_model=TransactionResponse)
def split_expense(payload: SplitExpenseCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    splits_dict = [s.dict() for s in payload.splits]
    return transaction_service.create_split_expense(
        db=db,
        payer_user_id=current_user.id,
        payer_source_id=payload.payer_source_id,
        total_amount_cents=payload.total_amount_cents,
        category=payload.category,
        description=payload.description,
        splits=splits_dict
    )
