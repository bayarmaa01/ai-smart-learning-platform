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
