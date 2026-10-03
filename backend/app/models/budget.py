import uuid
from datetime import datetime
from sqlalchemy import Column, String, BigInteger, Boolean, DateTime, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from app.database import Base

class Category(Base):
    __tablename__ = "categories"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=True)
    name = Column(String(100), nullable=False)
    type = Column(String(32), default="EXPENSE", nullable=False) # EXPENSE, INCOME
    icon = Column(String(64), default="category", nullable=False)
    is_custom = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class Budget(Base):
    __tablename__ = "budgets"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    organization_id = Column(String(36), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=True, index=True)
    category_id = Column(String(36), ForeignKey("categories.id", ondelete="CASCADE"), nullable=True)
    period = Column(String(32), default="MONTHLY", nullable=False) # MONTHLY, WEEKLY, YEARLY
    target_amount_cents = Column(BigInteger, nullable=False)
    alert_threshold_percentage = Column(Float, default=80.0, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    category = relationship("Category")

class RecurringRule(Base):
    __tablename__ = "recurring_transaction_rules"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    source_id = Column(String(36), ForeignKey("financial_sources.id"), nullable=True)
    category = Column(String(100), nullable=False)
    description = Column(String(255), nullable=False)
    amount_cents = Column(BigInteger, nullable=False)
    direction = Column(String(32), default="EXPENSE", nullable=False)
    frequency = Column(String(32), default="MONTHLY", nullable=False) # DAILY, WEEKLY, MONTHLY
    next_run_date = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    auto_confirm = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User")
    source = relationship("FinancialSource")
