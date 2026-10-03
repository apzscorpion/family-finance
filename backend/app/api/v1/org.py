from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.org import (
    OrganizationCreate, OrganizationUpdate, OrganizationResponse,
    MemberResponse, InvitationCreate, InvitationResponse, AcceptInvitationRequest,
    MemberUpdateRole, OwnershipTransferRequest
)
from app.services import org_service
from app.api.deps import get_current_user
from app.models.user import User
from app.models.organization import Organization, OrganizationMember

router = APIRouter(prefix="/organizations", tags=["Organizations"])

@router.post("", response_model=OrganizationResponse, status_code=status.HTTP_201_CREATED)
def create_org(payload: OrganizationCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    org = org_service.create_organization(
        db=db,
        owner_id=current_user.id,
        name=payload.name,
        description=payload.description
    )
    count = org_service.get_active_member_count(db, org.id)
    return OrganizationResponse(
        id=org.id,
        name=org.name,
        description=org.description,
        owner_id=org.owner_id,
        member_count=count,
        created_at=org.created_at,
        updated_at=org.updated_at
    )

@router.get("/{org_id}", response_model=OrganizationResponse)
def get_org(org_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    member = org_service.get_organization_member(db, org_id, current_user.id)
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this organization")
    
    org = db.query(Organization).filter(Organization.id == org_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
        
    count = org_service.get_active_member_count(db, org.id)
    return OrganizationResponse(
        id=org.id,
        name=org.name,
        description=org.description,
        owner_id=org.owner_id,
        member_count=count,
        created_at=org.created_at,
        updated_at=org.updated_at
    )

@router.get("/{org_id}/members", response_model=List[MemberResponse])
def list_members(org_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    member = org_service.get_organization_member(db, org_id, current_user.id)
    if not member:
        raise HTTPException(status_code=403, detail="Not authorized to view members")

    members = db.query(OrganizationMember).filter(
        OrganizationMember.organization_id == org_id,
        OrganizationMember.is_active == "ACTIVE"
    ).all()

    results = []
    for m in members:
        results.append(MemberResponse(
            id=m.id,
            organization_id=m.organization_id,
            user_id=m.user_id,
            user_full_name=m.user.full_name,
            user_email=m.user.email,
            user_phone=m.user.phone_number,
            relationship_label=m.relationship_label,
            role=m.role,
            is_active=m.is_active,
            joined_at=m.joined_at
        ))
    return results

@router.post("/{org_id}/invitations", response_model=InvitationResponse)
def invite_member(org_id: str, payload: InvitationCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    invitation = org_service.create_invitation(
        db=db,
        org_id=org_id,
        inviter_id=current_user.id,
        invitee_identifier=payload.invitee_identifier,
        relationship_label=payload.relationship_label,
        role=payload.role
    )
    return invitation

@router.post("/invitations/accept", response_model=MemberResponse)
def accept_invitation(payload: AcceptInvitationRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    member = org_service.accept_invitation(db=db, token=payload.token, user_id=current_user.id)
    return MemberResponse(
        id=member.id,
        organization_id=member.organization_id,
        user_id=member.user_id,
        user_full_name=current_user.full_name,
        user_email=current_user.email,
        user_phone=current_user.phone_number,
        relationship_label=member.relationship_label,
        role=member.role,
        is_active=member.is_active,
        joined_at=member.joined_at
    )

@router.delete("/{org_id}/members/{target_user_id}")
def remove_member(org_id: str, target_user_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return org_service.remove_member(db=db, org_id=org_id, target_user_id=target_user_id, requester_id=current_user.id)

@router.post("/{org_id}/leave")
def leave_org(org_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return org_service.leave_organization(db=db, org_id=org_id, user_id=current_user.id)

@router.post("/{org_id}/transfer-ownership")
def transfer_org_ownership(org_id: str, payload: OwnershipTransferRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return org_service.transfer_ownership(db=db, org_id=org_id, current_owner_id=current_user.id, new_owner_id=payload.new_owner_user_id)
