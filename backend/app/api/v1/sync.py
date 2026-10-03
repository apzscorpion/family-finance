from datetime import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sync import SyncPushRequest, SyncPushResponse, SyncPullResponse
from app.services.sync_service import process_push_mutations
from app.api.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/sync", tags=["Synchronization"])

@router.post("/push", response_model=SyncPushResponse)
def push_mutations(payload: SyncPushRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    results = process_push_mutations(db=db, user_id=current_user.id, mutations=payload.mutations)
    return SyncPushResponse(results=results)

@router.get("/pull", response_model=SyncPullResponse)
def pull_sync_data(since: float = 0.0, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    since_dt = datetime.utcfromtimestamp(since) if since > 0 else datetime.min
    
    return SyncPullResponse(
        server_timestamp=datetime.utcnow(),
        sources=[],
        transactions=[],
        proposals=[],
        organizations=[]
    )
