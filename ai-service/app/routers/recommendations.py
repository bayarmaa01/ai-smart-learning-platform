from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict, Optional

from app.services.recommendation_service import get_recommendations
from app.services.learning_path_service import (
    get_learning_path,
    get_skill_assessment,
)

router = APIRouter()


class RecommendationRequest(BaseModel):
    user_id: str
    enrolled_courses: List[Dict] = []
    language_preference: str = "en"
    limit: int = 6


class LearningPathRequest(BaseModel):
    user_goal: str
    current_level: str = "beginner"
    language_preference: str = "en"
    time_commitment: str = "medium"
    focus_areas: Optional[List[str]] = None


class SkillAssessmentRequest(BaseModel):
    user_skills: List[str]
    target_role: str
    language: str = "en"


@router.get("/{user_id}")
async def get_user_recommendations(user_id: str, language: str = "en"):
    """Get recommendations for a specific user."""
    recs = await get_recommendations(
        user_id=user_id,
        enrolled_courses=[],
        language_preference=language,
        limit=6,
    )
    return {"recommendations": recs, "user_id": user_id}


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


@router.post("/learning-path")
async def learning_path(request: LearningPathRequest):
    """Generate personalized learning path based on user goals."""
    path = get_learning_path(
        user_goal=request.user_goal,
        current_level=request.current_level,
        language_preference=request.language_preference,
        time_commitment=request.time_commitment,
        focus_areas=request.focus_areas,
    )
    return {"learning_path": path}


@router.post("/skill-assessment")
async def skill_assessment(request: SkillAssessmentRequest):
    """Assess user skills against target role requirements."""
    assessment = get_skill_assessment(
        user_skills=request.user_skills,
        target_role=request.target_role,
        language=request.language,
    )
    return {"assessment": assessment}
