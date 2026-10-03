import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, UniqueConstraint, Enum
import enum
from sqlalchemy.orm import relationship
from app.database import Base

class RoleEnum(str, enum.Enum):
    OWNER = "OWNER"
    ADMIN = "ADMIN"
    MEMBER = "MEMBER"
    READ_ONLY = "READ_ONLY"

class InvitationStatusEnum(str, enum.Enum):
    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"
    REVOKED = "REVOKED"

class Organization(Base):
    __tablename__ = "organizations"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    owner_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    members = relationship("OrganizationMember", back_populates="organization", cascade="all, delete-orphan")
    invitations = relationship("Invitation", back_populates="organization", cascade="all, delete-orphan")

class OrganizationMember(Base):
    __tablename__ = "organization_members"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    relationship_label = Column(String(64), default="Member", nullable=False) # Wife, Husband, Brother, etc.
    role = Column(String(32), default=RoleEnum.MEMBER.value, nullable=False)
    is_active = Column(String(32), default="ACTIVE", nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="members")
    user = relationship("User")

    __table_args__ = (
        UniqueConstraint("organization_id", "user_id", name="uq_org_member"),
    )

class Invitation(Base):
    __tablename__ = "invitations"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    inviter_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    invitee_identifier = Column(String(255), nullable=False) # Email or phone number
    relationship_label = Column(String(64), default="Member", nullable=False)
    role = Column(String(32), default=RoleEnum.MEMBER.value, nullable=False)
    token = Column(String(128), unique=True, index=True, nullable=False)
    status = Column(String(32), default=InvitationStatusEnum.PENDING.value, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    organization = relationship("Organization", back_populates="invitations")
    inviter = relationship("User", foreign_keys=[inviter_id])
