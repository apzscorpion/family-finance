import uuid
from datetime import datetime
from sqlalchemy import Column, String, BigInteger, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class FinancialSource(Base):
    __tablename__ = "financial_sources"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="SET NULL"), nullable=True, index=True)
    source_type = Column(String(64), nullable=False) # SALARY, BUSINESS, LOAN, POCKET_MONEY, GIFT, SAVINGS, RENTAL, CUSTOM
    display_name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    opening_balance_cents = Column(BigInteger, default=0, nullable=False) # Minor units (paisa)
    current_balance_cents = Column(BigInteger, default=0, nullable=False)
    currency = Column(String(3), default="INR", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    business_name = Column(String(255), nullable=True)
    business_description = Column(Text, nullable=True)
    loan_reference = Column(String(255), nullable=True)
    loan_details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    owner = relationship("User")
    organization = relationship("Organization")
