"""
Chat Service - Manages conversation history and AI responses
"""

import json
import logging
from typing import List, Optional, Dict
from datetime import datetime

from app.core.redis_client import delete_cache
from app.core.config import settings
from app.services.language_detector import detect_language, get_system_prompt
from app.services.llm_service import LLMMessage, get_provider

logger = logging.getLogger(__name__)


async def get_conversation_history(session_id: str) -> List[Dict]:
    """Retrieve conversation history from Redis cache."""
    cache_key = f"chat:history:{session_id}"
    history = await get_cache(cache_key)
    return history or []


async def save_conversation_history(
    session_id: str, history: List[Dict]
) -> None:
    """Save conversation history to Redis."""
    cache_key = f"chat:history:{session_id}"
    trimmed = history[-settings.MAX_HISTORY_MESSAGES :]
    await set_cache(cache_key, trimmed, ttl=86400)


async def process_chat(
    message: str,
    session_id: str,
    user_id: str,
    context: Optional[Dict] = None,
) -> Dict:
    """
    Process a chat message and return AI response.
    Automatically detects language and responds accordingly.
    """
    detected_lang, confidence = detect_language(message)
    logger.info(
        f"Language detected: {detected_lang} (confidence: {confidence:.2f}) for session: {session_id}"
    )

    history = await get_conversation_history(session_id)

    messages = [
        LLMMessage(role=m["role"], content=m["content"]) for m in history
    ]
    messages.append(LLMMessage(role="user", content=message))

    system_prompt = get_system_prompt(detected_lang, context)

    provider = get_provider()
    try:
        response = await provider.generate(
            messages=messages,
            system_prompt=system_prompt,
            max_tokens=settings.MAX_TOKENS,
            temperature=0.7,
        )
        ai_content = response.content
        tokens_used = response.tokens_used
    except Exception as e:
        logger.error(f"LLM generation error: {e}")
        if detected_lang == "mn":
            ai_content = "Уучлаарай, одоогоор хариулт өгөх боломжгүй байна. Дахин оролдоно уу."
        else:
            ai_content = "I apologize, I'm unable to respond right now. Please try again."
        tokens_used = 0

    history.append(
        {
            "role": "user",
            "content": message,
            "timestamp": datetime.utcnow().isoformat(),
        }
    )
    history.append(
        {
            "role": "assistant",
            "content": ai_content,
            "timestamp": datetime.utcnow().isoformat(),
        }
    )
    await save_conversation_history(session_id, history)

    return {
        "response": ai_content,
        "detected_language": detected_lang,
        "language_confidence": confidence,
        "tokens_used": tokens_used,
        "session_id": session_id,
        "sources": [],
    }


class ChatService:
    """Service class for chat operations."""

    @staticmethod
    async def get_history(session_id: str) -> list:
        """Get chat history for a session."""
        history = await get_conversation_history(session_id)
        return history or []

    @staticmethod
    async def clear_history(session_id: str) -> bool:
        """Clear chat history for a session."""
        try:
            await delete_conversation_history(session_id)
            return True
        except Exception:
            return False
