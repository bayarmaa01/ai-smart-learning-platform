from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from typing import Optional, Dict
import uuid

from app.services.chat_service import process_chat
from app.core.redis_client import increment_counter
from app.core.config import settings

router = APIRouter()


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    context: Optional[Dict] = None


class ChatResponse(BaseModel):
    response: str
    detected_language: str
    language_confidence: float
    tokens_used: int
    session_id: str
    sources: list = []


@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest, http_request: Request):
    """
    Process a chat message and return AI response.
    Automatically detects language (English/Mongolian) and responds accordingly.
    """
    session_id = request.session_id or str(uuid.uuid4())
    user_id = request.user_id or "anonymous"

    rate_key = f"ai:rate:{user_id}"
    count = await increment_counter(rate_key, 60)
    if count > settings.RATE_LIMIT_PER_MINUTE:
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded. Please slow down."
        )

    result = await process_chat(
        message=request.message,
        session_id=session_id,
        user_id=user_id,
        context=request.context,
    )

    return ChatResponse(**result)


@router.get("/history/{session_id}")
async def get_history(session_id: str):
    """Get chat history for a session."""
    from app.services.chat_service import get_conversation_history
    history = await get_conversation_history(session_id)
    return {"session_id": session_id, "messages": history}


@router.delete("/{session_id}")
async def clear_session(session_id: str):
    """Clear chat history for a session."""
    from app.core.redis_client import delete_cache
    await delete_cache(f"chat:history:{session_id}")
    return {"message": "Session cleared", "session_id": session_id}
