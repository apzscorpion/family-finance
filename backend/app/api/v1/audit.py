from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.audit import TransactionAuditLog
from app.models.organization import OrganizationMember, RoleEnum
from app.api.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/audit", tags=["Audit Logs"])

@router.get("")
def list_audit_logs(
    org_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if org_id:
        member = db.query(OrganizationMember).filter(
            OrganizationMember.organization_id == org_id,
            OrganizationMember.user_id == current_user.id,
            OrganizationMember.is_active == "ACTIVE"
        ).first()

        if not member or member.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
            raise HTTPException(status_code=403, detail="Only Organization Owner and Admins can view audit logs")

        logs = db.query(TransactionAuditLog).filter(TransactionAuditLog.organization_id == org_id).all()
    else:
        logs = db.query(TransactionAuditLog).filter(
            (TransactionAuditLog.actor_user_id == current_user.id) | (TransactionAuditLog.target_user_id == current_user.id)
        ).all()

    return logs
