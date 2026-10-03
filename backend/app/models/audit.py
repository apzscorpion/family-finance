import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class TransactionAuditLog(Base):
    __tablename__ = "transaction_audit_logs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    transaction_id = Column(String(36), nullable=False, index=True)
    organization_id = Column(String(36), nullable=True, index=True)
    actor_user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    target_user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    
    action_type = Column(String(64), nullable=False) 
    # CREATED, UPDATED, DELETED, PROPOSED, APPROVED, REJECTED, OWNER_OVERRIDE, REVERSED
    
    snapshot_before = Column(Text, nullable=True) # JSON snapshot
    snapshot_after = Column(Text, nullable=True) # JSON snapshot
    performed_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    actor = relationship("User", foreign_keys=[actor_user_id])
    target = relationship("User", foreign_keys=[target_user_id])
