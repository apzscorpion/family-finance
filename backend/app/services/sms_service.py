import re
from typing import Optional, Dict, Any
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.sms import SMSIngestionEvent
from app.models.transaction import Transaction

# Modular regex patterns for major Indian Bank & UPI SMS formats
BANK_PATTERNS = [
    # Format: Rs. 400.00 debited from account ... VPA merchant@upi Ref 123456...
    {
        "name": "UPI_DEBIT",
        "direction": "EXPENSE",
        "pattern": r"(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:debited|spent|paid|transferred).*?(?:to|at|vpa|info)?\s*([a-zA-Z0-9\.\_\-\s@]+)?.*?(?:ref|txn|trf|rrn|id)[:\s]*([a-zA-Z0-9]+)?",
        "flags": re.IGNORECASE
    },
    # Format: Rs. 1500.00 credited to account ... Ref 987654...
    {
        "name": "UPI_CREDIT",
        "direction": "INCOME",
        "pattern": r"(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:credited|received|deposited).*?(?:from|by|info)?\s*([a-zA-Z0-9\.\_\-\s@]+)?.*?(?:ref|txn|trf|rrn|id)[:\s]*([a-zA-Z0-9]+)?",
        "flags": re.IGNORECASE
    },
    # Format: Refund of Rs 250.00 processed ...
    {
        "name": "REFUND",
        "direction": "REFUND",
        "pattern": r"refund\s*(?:of)?\s*(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?).*?(?:from|at)?\s*([a-zA-Z0-9\.\_\-\s@]+)?",
        "flags": re.IGNORECASE
    }
]

def is_otp_or_auth_message(text: str) -> bool:
    """Filter out non-transaction messages such as OTPs or login codes."""
    lower_text = text.lower()
    otp_keywords = ["otp", "verification code", "one time password", "login code", "secret code", "do not share"]
    return any(kw in lower_text for kw in otp_keywords) and not ("debited" in lower_text or "credited" in lower_text)

def parse_sms_text(raw_sender: str, raw_message: str) -> Dict[str, Any]:
    if is_otp_or_auth_message(raw_message):
        return {
            "status": "IGNORED",
            "confidence": 0.0,
            "reason": "OTP or security message"
        }

    clean_msg = raw_message.replace("\n", " ").strip()
    
    # Try general amount extraction first
    amount_match = re.search(r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)", clean_msg, re.IGNORECASE)
    if not amount_match:
        return {
            "status": "IGNORED",
            "confidence": 0.0,
            "reason": "No valid monetary amount detected"
        }

    raw_amount_str = amount_match.group(1).replace(",", "")
    try:
        amount_float = float(raw_amount_str)
        amount_cents = int(round(amount_float * 100))
    except ValueError:
        return {"status": "IGNORED", "confidence": 0.0, "reason": "Amount parsing failure"}

    # Extract Direction
    direction = "UNKNOWN"
    lower_msg = clean_msg.lower()
    if "refund" in lower_msg or "reversed" in lower_msg:
        direction = "REFUND"
    elif "debited" in lower_msg or "paid" in lower_msg or "spent" in lower_msg or "sent" in lower_msg:
        direction = "EXPENSE"
    elif "credited" in lower_msg or "received" in lower_msg or "deposited" in lower_msg:
        direction = "INCOME"

    # Extract Reference ID
    ref_match = re.search(r"(?:ref|txn|rrn|utr|id)[:\s]*([a-zA-Z0-9]{6,20})", clean_msg, re.IGNORECASE)
    ref_id = ref_match.group(1) if ref_match else None

    # Extract Merchant / Payee candidate
    merchant = None
    merchant_match = re.search(r"(?:to|at|vpa|info|from)\s+([a-zA-Z0-9\.\_\-\s@]{3,30})", clean_msg, re.IGNORECASE)
    if merchant_match:
        candidate = merchant_match.group(1).strip()
        # Filter out common stop words
        if candidate.lower() not in ["your account", "bank", "ref", "upi", "inr", "rs"]:
            merchant = candidate

    confidence = 0.5
    if direction in ["EXPENSE", "INCOME", "REFUND"]:
        confidence += 0.3
    if ref_id:
        confidence += 0.15
    if merchant:
        confidence += 0.05

    status = "NEEDS_REVIEW"
    if confidence >= 0.9:
        status = "NEEDS_REVIEW" # Core safety: Candidate requires review/confirmation or user confirmation rules

    return {
        "status": status,
        "confidence": confidence,
        "amount_cents": amount_cents,
        "direction": direction,
        "merchant": merchant,
        "ref_id": ref_id,
        "payment_method": "UPI" if "upi" in lower_msg else ("CARD" if "card" in lower_msg else "BANK_TRANSFER")
    }

def ingest_sms_event(db: Session, user_id: str, raw_sender: str, raw_message: str) -> SMSIngestionEvent:
    parsed = parse_sms_text(raw_sender, raw_message)
    
    if parsed.get("status") == "IGNORED":
        event = SMSIngestionEvent(
            user_id=user_id,
            raw_sender=raw_sender,
            raw_message=raw_message,
            confidence_score=0.0,
            parsing_status="IGNORED"
        )
        db.add(event)
        db.commit()
        return event

    ref_id = parsed.get("ref_id")
    # Duplicate Detection against previously processed SMS events
    if ref_id:
        existing = db.query(SMSIngestionEvent).filter(
            SMSIngestionEvent.user_id == user_id,
            SMSIngestionEvent.parsed_ref_id == ref_id
        ).first()
        if existing:
            event = SMSIngestionEvent(
                user_id=user_id,
                raw_sender=raw_sender,
                raw_message=raw_message,
                parsed_amount_cents=parsed.get("amount_cents"),
                parsed_direction=parsed.get("direction"),
                parsed_merchant=parsed.get("merchant"),
                parsed_ref_id=ref_id,
                confidence_score=parsed.get("confidence"),
                parsing_status="DUPLICATE"
            )
            db.add(event)
            db.commit()
            return event

    event = SMSIngestionEvent(
        user_id=user_id,
        raw_sender=raw_sender,
        raw_message=raw_message,
        parsed_amount_cents=parsed.get("amount_cents"),
        parsed_direction=parsed.get("direction"),
        parsed_merchant=parsed.get("merchant"),
        parsed_ref_id=ref_id,
        parsed_payment_method=parsed.get("payment_method", "UPI"),
        confidence_score=parsed.get("confidence", 0.5),
        parsing_status=parsed.get("status", "NEEDS_REVIEW")
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event
