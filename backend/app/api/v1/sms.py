from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sms import SMSIngestRequest, SMSIngestResponse, SMSReviewAction
from app.services import sms_service, transaction_service
from app.api.deps import get_current_user
from app.models.user import User
from app.models.sms import SMSIngestionEvent

router = APIRouter(prefix="/sms", tags=["Android SMS Ingestion"])

@router.post("/ingest", response_model=SMSIngestResponse)
def ingest_sms(payload: SMSIngestRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    event = sms_service.ingest_sms_event(
        db=db,
        user_id=current_user.id,
        raw_sender=payload.raw_sender,
        raw_message=payload.raw_message
    )
    return event

@router.get("/pending", response_model=List[SMSIngestResponse])
def get_pending_sms_reviews(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(SMSIngestionEvent).filter(
        SMSIngestionEvent.user_id == current_user.id,
        SMSIngestionEvent.parsing_status == "NEEDS_REVIEW"
    ).order_by(SMSIngestionEvent.created_at.desc()).all()

@router.post("/{event_id}/review")
def review_sms_event(event_id: str, payload: SMSReviewAction, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    event = db.query(SMSIngestionEvent).filter(
        SMSIngestionEvent.id == event_id,
        SMSIngestionEvent.user_id == current_user.id
    ).first()

    if not event:
        raise HTTPException(status_code=404, detail="SMS Ingestion event not found")

    if payload.action == "REJECT":
        event.parsing_status = "IGNORED"
        db.commit()
        return {"message": "SMS transaction rejected"}

    elif payload.action in ["CONFIRM", "EDIT"]:
        amount_cents = payload.amount_cents or event.parsed_amount_cents
        if not amount_cents:
            raise HTTPException(status_code=400, detail="Amount required to confirm SMS transaction")

        txn = transaction_service.create_transaction(
            db=db,
            creator_id=current_user.id,
            target_user_id=current_user.id,
            amount_cents=amount_cents,
            direction=event.parsed_direction or "EXPENSE",
            category=payload.category or "Unclassified",
            source_id=payload.source_id,
            merchant_or_payee=payload.merchant_or_payee or event.parsed_merchant,
            payment_method=event.parsed_payment_method or "UPI",
            entry_origin="SMS",
            verification_status="CONFIRMED",
            description=f"Auto-parsed from SMS ({event.raw_sender})"
        )

        event.resulting_transaction_id = txn.id
        event.parsing_status = "AUTO_CONFIRMED"
        db.commit()
        return {"message": "SMS transaction confirmed", "transaction_id": txn.id}

    raise HTTPException(status_code=400, detail="Invalid action")
