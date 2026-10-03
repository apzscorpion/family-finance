from fastapi import FastAPI
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

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.ENV,
        "max_org_members": settings.MAX_ORGANIZATION_MEMBERS
    }
