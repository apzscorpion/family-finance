from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class OrganizationCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    description: Optional[str] = None

class OrganizationUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None

class MemberResponse(BaseModel):
    id: str
    organization_id: str
    user_id: str
    user_full_name: str
    user_email: str
    user_phone: Optional[str] = None
    relationship_label: str
    role: str
    is_active: str
    joined_at: datetime

    class Config:
        from_attributes = True

class OrganizationResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    owner_id: str
    member_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class InvitationCreate(BaseModel):
    invitee_identifier: str # Email or phone number
    relationship_label: str = "Family Member" # Wife, Husband, Brother, Cousin, Friend, Son, Daughter, Father, Mother, Custom
    role: str = "MEMBER" # ADMIN, MEMBER, READ_ONLY

class InvitationResponse(BaseModel):
    id: str
    organization_id: str
    inviter_id: str
    invitee_identifier: str
    relationship_label: str
    role: str
    token: str
    status: str
    expires_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True

class AcceptInvitationRequest(BaseModel):
    token: str

class MemberUpdateRole(BaseModel):
    relationship_label: Optional[str] = None
    role: Optional[str] = None

class OwnershipTransferRequest(BaseModel):
    new_owner_user_id: str
