from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.source import SourceCreate, SourceUpdate, SourceResponse
from app.models.source import FinancialSource
from app.models.organization import OrganizationMember, RoleEnum
from app.api.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/sources", tags=["Financial Sources"])

@router.post("", response_model=SourceResponse, status_code=status.HTTP_201_CREATED)
def create_source(payload: SourceCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    source = FinancialSource(
        owner_id=current_user.id,
        organization_id=payload.organization_id,
        source_type=payload.source_type,
        display_name=payload.display_name,
        description=payload.description,
        opening_balance_cents=payload.opening_balance_cents,
        current_balance_cents=payload.opening_balance_cents,
        currency=payload.currency,
        business_name=payload.business_name,
        business_description=payload.business_description,
        loan_reference=payload.loan_reference,
        loan_details=payload.loan_details
    )
    db.add(source)
    db.commit()
    db.refresh(source)
    return source

@router.get("", response_model=List[SourceResponse])
def list_sources(
    target_user_id: Optional[str] = None,
    org_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    query = db.query(FinancialSource).filter(FinancialSource.is_active == True)

    effective_user_id = target_user_id or current_user.id

    if effective_user_id != current_user.id:
        # Member context switching authorization
        if not org_id:
            raise HTTPException(status_code=403, detail="Cannot access another user's financial sources without organization context")
        
        # Check requester member status
        requester_member = db.query(OrganizationMember).filter(
            OrganizationMember.organization_id == org_id,
            OrganizationMember.user_id == current_user.id,
            OrganizationMember.is_active == "ACTIVE"
        ).first()

        if not requester_member or requester_member.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
            raise HTTPException(status_code=403, detail="Not authorized to view other member's financial sources")

    query = query.filter(FinancialSource.owner_id == effective_user_id)
    if org_id:
        query = query.filter(FinancialSource.organization_id == org_id)

    return query.all()
