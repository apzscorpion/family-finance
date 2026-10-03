import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Integer
from sqlalchemy.orm import relationship
from app.database import Base

class TransactionProposal(Base):
    __tablename__ = "transaction_proposals"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    target_transaction_id = Column(String(36), ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True)
    target_user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    proposer_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    
    proposal_type = Column(String(32), nullable=False) # ADDITION, EDIT, DELETION
    proposed_data = Column(Text, nullable=False) # JSON payload of proposed fields
    original_data = Column(Text, nullable=True) # JSON snapshot of original fields
    target_version = Column(Integer, nullable=True) # Version for optimistic lock validation
    
    reason = Column(Text, nullable=True)
    status = Column(String(32), default="PENDING", nullable=False, index=True) # DRAFT, PENDING, APPROVED, REJECTED, CANCELLED, EXPIRED, CONFLICT
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    target_user = relationship("User", foreign_keys=[target_user_id])
    proposer = relationship("User", foreign_keys=[proposer_id])
    target_transaction = relationship("Transaction")
    decisions = relationship("ApprovalDecision", back_populates="proposal", cascade="all, delete-orphan")

class ApprovalDecision(Base):
    __tablename__ = "approval_decisions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    proposal_id = Column(String(36), ForeignKey("transaction_proposals.id", ondelete="CASCADE"), nullable=False)
    reviewer_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    decision = Column(String(32), nullable=False) # APPROVED, REJECTED
    rejection_reason = Column(Text, nullable=True)
    decision_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    proposal = relationship("TransactionProposal", back_populates="decisions")
    reviewer = relationship("User")
