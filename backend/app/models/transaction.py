import uuid
from datetime import datetime
from sqlalchemy import Column, String, BigInteger, Boolean, DateTime, ForeignKey, Text, Integer
from sqlalchemy.orm import relationship
from app.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="SET NULL"), nullable=True, index=True)
    source_id = Column(String(36), ForeignKey("financial_sources.id"), nullable=True)
    
    amount_cents = Column(BigInteger, nullable=False) # Minor units (paisa)
    currency = Column(String(3), default="INR", nullable=False)
    direction = Column(String(32), nullable=False) # INCOME, EXPENSE, TRANSFER_IN, TRANSFER_OUT, REFUND, LOAN_DISBURSEMENT
    category = Column(String(100), default="Unclassified", nullable=False)
    description = Column(Text, nullable=True)
    merchant_or_payee = Column(String(255), nullable=True)
    payment_method = Column(String(64), default="OTHER", nullable=False) # CASH, UPI, BANK_TRANSFER, CARD
    date_time = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    entry_origin = Column(String(32), default="MANUAL", nullable=False) # MANUAL, SMS, NOTIFICATION, RECURRING
    verification_status = Column(String(32), default="CONFIRMED", nullable=False, index=True) # CONFIRMED, PENDING_REVIEW, PROPOSED, REJECTED, VOIDED
    
    created_by_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    last_modified_by_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    
    notes = Column(Text, nullable=True)
    receipt_url = Column(Text, nullable=True)
    
    version = Column(Integer, default=1, nullable=False) # Optimistic concurrency
    is_deleted = Column(Boolean, default=False, nullable=False)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    owner = relationship("User", foreign_keys=[owner_id])
    created_by = relationship("User", foreign_keys=[created_by_id])
    last_modified_by = relationship("User", foreign_keys=[last_modified_by_id])
    source = relationship("FinancialSource")

class TransactionTransfer(Base):
    __tablename__ = "transaction_transfers"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    transfer_group_id = Column(String(36), nullable=False, index=True) # Shared UUID linking both legs
    debit_transaction_id = Column(String(36), ForeignKey("transactions.id"), nullable=False)
    credit_transaction_id = Column(String(36), ForeignKey("transactions.id"), nullable=False)
    from_user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    to_user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    status = Column(String(32), default="CONFIRMED", nullable=False) # CONFIRMED, PENDING, REJECTED
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    debit_transaction = relationship("Transaction", foreign_keys=[debit_transaction_id])
    credit_transaction = relationship("Transaction", foreign_keys=[credit_transaction_id])

class TransactionSplit(Base):
    __tablename__ = "transaction_splits"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    transaction_id = Column(String(36), ForeignKey("transactions.id", ondelete="CASCADE"), nullable=False)
    beneficiary_user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    split_amount_cents = Column(BigInteger, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    transaction = relationship("Transaction")
    beneficiary = relationship("User")
