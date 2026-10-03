import uuid
from datetime import datetime
from sqlalchemy import Column, String, BigInteger, Boolean, DateTime, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from app.database import Base

class SMSIngestionEvent(Base):
    __tablename__ = "sms_ingestion_events"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    raw_sender = Column(String(64), nullable=False)
    raw_message = Column(Text, nullable=False)
    
    parsed_amount_cents = Column(BigInteger, nullable=True)
    parsed_direction = Column(String(32), nullable=True) # EXPENSE, INCOME, REFUND, UNKNOWN
    parsed_merchant = Column(String(255), nullable=True)
    parsed_ref_id = Column(String(128), nullable=True, index=True)
    parsed_payment_method = Column(String(64), default="UPI", nullable=False)
    
    confidence_score = Column(Float, default=0.0, nullable=False)
    parsing_status = Column(String(32), default="NEEDS_REVIEW", nullable=False) 
    # AUTO_CONFIRMED, NEEDS_REVIEW, IGNORED, DUPLICATE, ERROR
    
    resulting_transaction_id = Column(String(36), ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User")
    resulting_transaction = relationship("Transaction")

class SMSParserRule(Base):
    __tablename__ = "sms_parser_rules"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    bank_name = Column(String(100), nullable=False)
    sender_pattern = Column(String(100), nullable=False) # e.g. "HDFCBK", "ICICIB", "SBIINB"
    amount_regex = Column(String(255), nullable=False)
    merchant_regex = Column(String(255), nullable=True)
    ref_regex = Column(String(255), nullable=True)
    direction = Column(String(32), default="EXPENSE", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
