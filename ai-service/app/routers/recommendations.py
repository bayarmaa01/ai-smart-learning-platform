from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict, Optional

from app.services.recommendation_service import get_recommendations

router = APIRouter()


class RecommendationRequest(BaseModel):
    user_id: str
    enrolled_courses: List[Dict] = []
    language_preference: str = "en"
    limit: int = 6


@router.post("")
async def recommendations(request: RecommendationRequest):
    """Get personalized course recommendations."""
    recs = await get_recommendations(
        user_id=request.user_id,
        enrolled_courses=request.enrolled_courses,
        language_preference=request.language_preference,
        limit=request.limit,
    )
    return {"recommendations": recs, "user_id": request.user_id}
