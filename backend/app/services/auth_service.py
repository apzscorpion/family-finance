import uuid
import hashlib
import os
from datetime import datetime, timedelta
from typing import Optional
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.config import settings
from app.models.user import User, UserProfile, UserSession

def hash_password(password: str) -> str:
    """Secure PBKDF2 password hashing with random salt."""
    salt = os.urandom(16)
    pwd_hash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return salt.hex() + ":" + pwd_hash.hex()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        salt_hex, hash_hex = hashed_password.split(":")
        salt = bytes.fromhex(salt_hex)
        pwd_hash = hashlib.pbkdf2_hmac('sha256', plain_password.encode('utf-8'), salt, 100000)
        return pwd_hash.hex() == hash_hex
    except Exception:
        return False

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def create_refresh_token(data: dict) -> tuple[str, str, datetime]:
    jti = str(uuid.uuid4())
    expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = data.copy()
    to_encode.update({"exp": expires_at, "jti": jti, "type": "refresh"})
    token = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return token, jti, expires_at

def register_user(db: Session, email: str, password: str, full_name: str, phone_number: Optional[str] = None, default_currency: str = "INR") -> User:
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User with this email already exists")
    
    if phone_number:
        existing_phone = db.query(User).filter(User.phone_number == phone_number).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail="User with this phone number already exists")

    hashed_pw = hash_password(password)
    new_user = User(
        email=email,
        hashed_password=hashed_pw,
        full_name=full_name,
        phone_number=phone_number,
        default_currency=default_currency
    )
    db.add(new_user)
    db.flush()

    user_profile = UserProfile(user_id=new_user.id)
    db.add(user_profile)
    db.commit()
    db.refresh(new_user)
    return new_user

def authenticate_user(db: Session, email: str, password: str, device_info: Optional[str] = None):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="User account is deactivated")

    access_token = create_access_token({"sub": user.id, "email": user.email})
    refresh_token, jti, expires_at = create_refresh_token({"sub": user.id})

    session = UserSession(
        user_id=user.id,
        jti=jti,
        device_info=device_info,
        expires_at=expires_at
    )
    db.add(session)
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "user": user
    }

def refresh_session_token(db: Session, refresh_token: str):
    try:
        payload = jwt.decode(refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")
        
        user_id = payload.get("sub")
        jti = payload.get("jti")
        
        session = db.query(UserSession).filter(UserSession.jti == jti, UserSession.is_revoked == False).first()
        if not session:
            raise HTTPException(status_code=401, detail="Session revoked or invalid")

        user = db.query(User).filter(User.id == user_id).first()
        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="User unavailable")

        # Revoke old session and issue new pair
        session.is_revoked = True
        
        new_access_token = create_access_token({"sub": user.id, "email": user.email})
        new_refresh_token, new_jti, new_expires_at = create_refresh_token({"sub": user.id})

        new_session = UserSession(
            user_id=user.id,
            jti=new_jti,
            device_info=session.device_info,
            expires_at=new_expires_at
        )
        db.add(new_session)
        db.commit()

        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user": user
        }
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

def logout_session(db: Session, user_id: str, jti: Optional[str] = None):
    query = db.query(UserSession).filter(UserSession.user_id == user_id)
    if jti:
        query = query.filter(UserSession.jti == jti)
    query.update({"is_revoked": True})
    db.commit()
    return {"message": "Logged out successfully"}
