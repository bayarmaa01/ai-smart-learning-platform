import json
import logging
from typing import Any, Optional
import redis.asyncio as aioredis
from app.core.config import settings

logger = logging.getLogger(__name__)
redis_client: Optional[aioredis.Redis] = None


async def init_redis():
    global redis_client
    try:
        redis_client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
        )
        await redis_client.ping()
        logger.info("Redis connected successfully")
    except Exception as e:
        logger.warning(f"Redis connection failed: {e}. Running without cache.")
        redis_client = None


async def close_redis():
    global redis_client
    if redis_client:
        await redis_client.close()


async def get_cache(key: str) -> Optional[Any]:
    if not redis_client:
        return None
    try:
        data = await redis_client.get(key)
        return json.loads(data) if data else None
    except Exception as e:
        logger.error(f"Redis GET error: {e}")
        return None


async def set_cache(key: str, value: Any, ttl: int = None) -> bool:
    if not redis_client:
        return False
    try:
        await redis_client.setex(
            key, ttl or settings.REDIS_TTL, json.dumps(value)
        )
        return True
    except Exception as e:
        logger.error(f"Redis SET error: {e}")
        return False


async def delete_cache(key: str) -> bool:
    if not redis_client:
        return False
    try:
        await redis_client.delete(key)
        return True
    except Exception as e:
        logger.error(f"Redis DEL error: {e}")
        return False


async def increment_counter(key: str, ttl: int = 3600) -> int:
    if not redis_client:
        return 0
    try:
        count = await redis_client.incr(key)
        if count == 1:
            await redis_client.expire(key, ttl)
        return count
    except Exception as e:
        logger.error(f"Redis INCR error: {e}")
        return 0
