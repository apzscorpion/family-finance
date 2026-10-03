from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime

class OfflineMutation(BaseModel):
    client_mutation_id: str
    entity_type: str # TRANSACTION, SOURCE, PROPOSAL
    action: str # CREATE, UPDATE, DELETE
    data: Dict[str, Any]
    client_timestamp: datetime

class SyncPushRequest(BaseModel):
    mutations: List[OfflineMutation]

class SyncPushResult(BaseModel):
    client_mutation_id: str
    status: str # SUCCESS, CONFLICT, ERROR
    server_id: Optional[str] = None
    error_message: Optional[str] = None

class SyncPushResponse(BaseModel):
    results: List[SyncPushResult]

class SyncPullResponse(BaseModel):
    server_timestamp: datetime
    sources: List[Dict[str, Any]]
    transactions: List[Dict[str, Any]]
    proposals: List[Dict[str, Any]]
    organizations: List[Dict[str, Any]]
