import secrets
from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from app.config import settings
from app.models.organization import Organization, OrganizationMember, Invitation, RoleEnum, InvitationStatusEnum
from app.models.user import User

def create_organization(db: Session, owner_id: str, name: str, description: Optional[str] = None) -> Organization:
    org = Organization(
        name=name,
        description=description,
        owner_id=owner_id
    )
    db.add(org)
    db.flush()

    member = OrganizationMember(
        organization_id=org.id,
        user_id=owner_id,
        relationship_label="Self",
        role=RoleEnum.OWNER.value,
        is_active="ACTIVE"
    )
    db.add(member)
    db.commit()
    db.refresh(org)
    return org

def get_organization_member(db: Session, org_id: str, user_id: str) -> Optional[OrganizationMember]:
    return db.query(OrganizationMember).filter(
        OrganizationMember.organization_id == org_id,
        OrganizationMember.user_id == user_id,
        OrganizationMember.is_active == "ACTIVE"
    ).first()

def get_active_member_count(db: Session, org_id: str) -> int:
    return db.query(func.count(OrganizationMember.id)).filter(
        OrganizationMember.organization_id == org_id,
        OrganizationMember.is_active == "ACTIVE"
    ).scalar() or 0

def create_invitation(
    db: Session,
    org_id: str,
    inviter_id: str,
    invitee_identifier: str,
    relationship_label: str = "Family Member",
    role: str = RoleEnum.MEMBER.value
) -> Invitation:
    # Check inviter permissions (Must be OWNER or ADMIN)
    inviter_member = get_organization_member(db, org_id, inviter_id)
    if not inviter_member or inviter_member.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
        raise HTTPException(status_code=403, detail="Only Owners and Admins can create invitations")

    # Atomic capacity check before issuing invitation
    current_count = get_active_member_count(db, org_id)
    if current_count >= settings.MAX_ORGANIZATION_MEMBERS:
        raise HTTPException(status_code=400, detail=f"Organization has reached maximum limit of {settings.MAX_ORGANIZATION_MEMBERS} members")

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=settings.INVITATION_TOKEN_EXPIRE_HOURS)

    invitation = Invitation(
        organization_id=org_id,
        inviter_id=inviter_id,
        invitee_identifier=invitee_identifier,
        relationship_label=relationship_label,
        role=role,
        token=token,
        expires_at=expires_at,
        status=InvitationStatusEnum.PENDING.value
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)
    return invitation

def accept_invitation(db: Session, token: str, user_id: str) -> OrganizationMember:
    invitation = db.query(Invitation).filter(Invitation.token == token).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")

    if invitation.status != InvitationStatusEnum.PENDING.value:
        raise HTTPException(status_code=400, detail=f"Invitation is already {invitation.status.lower()}")

    if datetime.utcnow() > invitation.expires_at:
        invitation.status = InvitationStatusEnum.EXPIRED.value
        db.commit()
        raise HTTPException(status_code=400, detail="Invitation token has expired")

    # Atomic server-side member count check to prevent exceeding 30 members during concurrent accepts
    active_count = get_active_member_count(db, invitation.organization_id)
    if active_count >= settings.MAX_ORGANIZATION_MEMBERS:
        invitation.status = InvitationStatusEnum.EXPIRED.value
        db.commit()
        raise HTTPException(status_code=400, detail=f"Organization has reached its maximum capacity of {settings.MAX_ORGANIZATION_MEMBERS} members")

    # Check if user is already an active member
    existing_member = get_organization_member(db, invitation.organization_id, user_id)
    if existing_member:
        invitation.status = InvitationStatusEnum.ACCEPTED.value
        db.commit()
        return existing_member

    # Create new organization member
    member = OrganizationMember(
        organization_id=invitation.organization_id,
        user_id=user_id,
        relationship_label=invitation.relationship_label,
        role=invitation.role,
        is_active="ACTIVE"
    )
    invitation.status = InvitationStatusEnum.ACCEPTED.value
    db.add(member)
    db.commit()
    db.refresh(member)
    return member

def reject_invitation(db: Session, token: str, user_id: str):
    invitation = db.query(Invitation).filter(Invitation.token == token).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.status != InvitationStatusEnum.PENDING.value:
        raise HTTPException(status_code=400, detail="Invitation is no longer pending")
    
    invitation.status = InvitationStatusEnum.REJECTED.value
    db.commit()
    return {"message": "Invitation rejected"}

def revoke_invitation(db: Session, invitation_id: str, requester_id: str):
    invitation = db.query(Invitation).filter(Invitation.id == invitation_id).first()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")

    requester_member = get_organization_member(db, invitation.organization_id, requester_id)
    if not requester_member or requester_member.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
        raise HTTPException(status_code=403, detail="Not authorized to revoke invitation")

    invitation.status = InvitationStatusEnum.REVOKED.value
    db.commit()
    return {"message": "Invitation revoked"}

def remove_member(db: Session, org_id: str, target_user_id: str, requester_id: str):
    requester = get_organization_member(db, org_id, requester_id)
    if not requester or requester.role not in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
        raise HTTPException(status_code=403, detail="Only Owners and Admins can remove members")

    target = get_organization_member(db, org_id, target_user_id)
    if not target:
        raise HTTPException(status_code=404, detail="Member not found in organization")

    if target.role == RoleEnum.OWNER.value:
        raise HTTPException(status_code=400, detail="Cannot remove the organization owner. Transfer ownership first.")

    if requester.role == RoleEnum.ADMIN.value and target.role in [RoleEnum.OWNER.value, RoleEnum.ADMIN.value]:
        raise HTTPException(status_code=403, detail="Admins cannot remove Owners or other Admins")

    target.is_active = "REMOVED"
    db.commit()
    return {"message": "Member removed from organization"}

def leave_organization(db: Session, org_id: str, user_id: str):
    member = get_organization_member(db, org_id, user_id)
    if not member:
        raise HTTPException(status_code=404, detail="You are not an active member of this organization")

    if member.role == RoleEnum.OWNER.value:
        # Count remaining members
        count = get_active_member_count(db, org_id)
        if count > 1:
            raise HTTPException(status_code=400, detail="As the owner, you must transfer ownership to another member before leaving")

    member.is_active = "REMOVED"
    db.commit()
    return {"message": "Successfully left organization"}

def transfer_ownership(db: Session, org_id: str, current_owner_id: str, new_owner_id: str):
    org = db.query(Organization).filter(Organization.id == org_id, Organization.owner_id == current_owner_id).first()
    if not org:
        raise HTTPException(status_code=403, detail="Only the current organization owner can transfer ownership")

    new_owner_member = get_organization_member(db, org_id, new_owner_id)
    if not new_owner_member:
        raise HTTPException(status_code=404, detail="Target user is not an active member of this organization")

    current_owner_member = get_organization_member(db, org_id, current_owner_id)
    
    org.owner_id = new_owner_id
    new_owner_member.role = RoleEnum.OWNER.value
    if current_owner_member:
        current_owner_member.role = RoleEnum.ADMIN.value

    db.commit()
    return {"message": f"Ownership transferred to member {new_owner_id}"}
