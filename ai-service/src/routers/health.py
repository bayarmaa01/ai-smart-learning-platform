from fastapi import APIRouter
from datetime import datetime
import platform

router = APIRouter()


@router.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "ai-service",
        "python": platform.python_version(),
    }


@router.get("/")
async def root():
    return {"message": "EduAI AI Service", "version": "1.0.0", "docs": "/docs"}


@router.get("/ready")
async def readiness():
    return {
        "status": "ready",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "ai-service",
    }


@router.get("/live")
async def liveness():
    return {
        "status": "alive",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "ai-service",
    }
