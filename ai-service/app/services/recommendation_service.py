"""
AI Recommendation Engine
Uses collaborative filtering + content-based filtering
"""

import logging
from typing import List, Dict, Optional
import numpy as np

logger = logging.getLogger(__name__)


def compute_similarity(user_categories: List[str], course_categories: List[str]) -> float:
    """Simple Jaccard similarity for category matching."""
    if not user_categories or not course_categories:
        return 0.0
    user_set = set(user_categories)
    course_set = set(course_categories)
    intersection = len(user_set & course_set)
    union = len(user_set | course_set)
    return intersection / union if union > 0 else 0.0


def get_level_score(user_level: str, course_level: str) -> float:
    """Score based on appropriate difficulty level."""
    levels = {'beginner': 0, 'intermediate': 1, 'advanced': 2}
    user_l = levels.get(user_level, 0)
    course_l = levels.get(course_level, 0)
    diff = abs(user_l - course_l)
    return max(0, 1 - diff * 0.4)


async def get_recommendations(
    user_id: str,
    enrolled_courses: List[Dict],
    language_preference: str = 'en',
    limit: int = 6,
) -> List[Dict]:
    """
    Generate personalized course recommendations.
    In production, this would query the database and use ML models.
    """
    user_categories = list({c.get('category_id', '') for c in enrolled_courses if c.get('category_id')})
    user_levels = [c.get('level', 'beginner') for c in enrolled_courses]
    avg_level = 'intermediate' if len(user_levels) > 2 else 'beginner'

    mock_recommendations = [
        {
            "id": "rec-1",
            "title": "Advanced Machine Learning" if language_preference == 'en' else "Дэвшилтэт Машин Сургалт",
            "instructor": "Dr. Sarah Chen",
            "rating": 4.9,
            "students": 28400,
            "price": 0,
            "level": "advanced",
            "reason": "Based on your ML courses" if language_preference == 'en' else "Таны ML хичээлүүд дээр үндэслэн",
        },
        {
            "id": "rec-2",
            "title": "Python Data Structures" if language_preference == 'en' else "Python Өгөгдлийн Бүтэц",
            "instructor": "Emma Wilson",
            "rating": 4.7,
            "students": 45200,
            "price": 0,
            "level": "intermediate",
            "reason": "Popular in your field" if language_preference == 'en' else "Таны чиглэлд алдартай",
        },
        {
            "id": "rec-3",
            "title": "Cloud Architecture Patterns" if language_preference == 'en' else "Клауд Архитектурын Загварууд",
            "instructor": "Mike Johnson",
            "rating": 4.8,
            "students": 19800,
            "price": 49.99,
            "level": "advanced",
            "reason": "Trending this week" if language_preference == 'en' else "Энэ долоо хоногт тренд",
        },
    ]

    return mock_recommendations[:limit]
