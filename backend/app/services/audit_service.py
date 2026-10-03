import json
from typing import Optional, Any, Dict
from sqlalchemy.orm import Session
from app.models.audit import TransactionAuditLog

def log_transaction_audit(
    db: Session,
    transaction_id: str,
    actor_user_id: str,
    target_user_id: str,
    action_type: str, # CREATED, UPDATED, DELETED, PROPOSED, APPROVED, REJECTED, OWNER_OVERRIDE, REVERSED
    organization_id: Optional[str] = None,
    snapshot_before: Optional[Dict[str, Any]] = None,
    snapshot_after: Optional[Dict[str, Any]] = None
) -> TransactionAuditLog:
    log_entry = TransactionAuditLog(
        transaction_id=transaction_id,
        organization_id=organization_id,
        actor_user_id=actor_user_id,
        target_user_id=target_user_id,
        action_type=action_type,
        snapshot_before=json.dumps(snapshot_before) if snapshot_before else None,
        snapshot_after=json.dumps(snapshot_after) if snapshot_after else None
    )
    db.add(log_entry)
    db.flush()
    return log_entry
