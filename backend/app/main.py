import json
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import Base, engine
from app.api.v1 import (
    auth, org, sources, transactions, approvals, dashboards, sms, budgets, sync, audit
)

# Auto-create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="Production-ready backend API for Shared Family & Personal Finance Manager with Indian SMS parsing, 30-member organization limit, collaborative approval workflows, member switcher, and offline sync.",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Versioned API v1 Routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(org.router, prefix="/api/v1")
app.include_router(sources.router, prefix="/api/v1")
app.include_router(transactions.router, prefix="/api/v1")
app.include_router(approvals.router, prefix="/api/v1")
app.include_router(dashboards.router, prefix="/api/v1")
app.include_router(sms.router, prefix="/api/v1")
app.include_router(budgets.router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")
app.include_router(audit.router, prefix="/api/v1")


class FamilyNotesRoomHub:
    def __init__(self) -> None:
        self.rooms: Dict[str, List[WebSocket]] = {}
        self.room_notes: Dict[str, Dict[str, dict]] = {}
        self.room_metadata: Dict[str, dict] = {}

    async def connect(self, room_code: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.rooms.setdefault(room_code, []).append(websocket)
        existing_meta = self.room_metadata.get(room_code)
        if existing_meta:
            await websocket.send_text(json.dumps({
                "event": "group_workspace_sync",
                "payload": {
                    "sender": "Server",
                    **existing_meta,
                }
            }))
        existing = list(self.room_notes.get(room_code, {}).values())
        if existing:
            await websocket.send_text(json.dumps({
                "event": "notes_full_sync",
                "payload": {
                    "sender": "Server",
                    "notes": existing,
                }
            }))

    def disconnect(self, room_code: str, websocket: WebSocket) -> None:
        if room_code in self.rooms and websocket in self.rooms[room_code]:
            self.rooms[room_code].remove(websocket)

    async def broadcast(self, room_code: str, message: str, sender_ws: WebSocket) -> None:
        try:
            parsed = json.loads(message)
            event = parsed.get("event")
            payload = parsed.get("payload", {})
            if event == "note_live_edit" and isinstance(payload.get("note"), dict):
                note_obj = payload["note"]
                note_id = str(note_obj.get("id", ""))
                if note_id:
                    self.room_notes.setdefault(room_code, {})[note_id] = note_obj
            elif event == "note_delete":
                note_id = str(payload.get("noteId", ""))
                if note_id and room_code in self.room_notes:
                    self.room_notes[room_code].pop(note_id, None)
            elif event == "notes_full_sync" and isinstance(payload.get("notes"), list):
                for n in payload["notes"]:
                    if isinstance(n, dict) and n.get("id"):
                        self.room_notes.setdefault(room_code, {})[str(n["id"])] = n
            elif event == "group_workspace_sync":
                meta = self.room_metadata.setdefault(room_code, {})
                if payload.get("familyName"):
                    meta["familyName"] = payload["familyName"]
                if payload.get("groupKind"):
                    meta["groupKind"] = payload["groupKind"]
                if payload.get("ownerEmail"):
                    meta["ownerEmail"] = payload["ownerEmail"]
                if isinstance(payload.get("members"), list):
                    meta["members"] = payload["members"]
                if isinstance(payload.get("transactions"), list):
                    meta["transactions"] = payload["transactions"]
        except Exception:
            pass

        dead: List[WebSocket] = []
        for ws in self.rooms.get(room_code, []):
            if ws is sender_ws:
                continue
            try:
                await ws.send_text(message)
            except Exception:
                dead.append(ws)
        for d in dead:
            self.disconnect(room_code, d)


notes_hub = FamilyNotesRoomHub()


@app.websocket("/ws/notes/{family_code}")
async def family_notes_ws(websocket: WebSocket, family_code: str):
    code = family_code.strip().upper()
    await notes_hub.connect(code, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await notes_hub.broadcast(code, data, websocket)
    except WebSocketDisconnect:
        notes_hub.disconnect(code, websocket)
    except Exception:
        notes_hub.disconnect(code, websocket)


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.ENV,
        "max_org_members": settings.MAX_ORGANIZATION_MEMBERS
    }
