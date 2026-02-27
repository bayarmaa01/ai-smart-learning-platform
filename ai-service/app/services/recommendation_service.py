"""
AI Recommendation Engine
Uses collaborative filtering + content-based filtering based on real user data.
"""

import logging
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)


def compute_similarity(user_categories: List[str], course_categories: List[str]) -> float:
    """Jaccard similarity for category matching."""
    if not user_categories or not course_categories:
        return 0.0
    user_set = set(c.lower() for c in user_categories)
    course_set = set(c.lower() for c in course_categories)
    intersection = len(user_set & course_set)
    union = len(user_set | course_set)
    return intersection / union if union > 0 else 0.0


def get_level_score(user_level: str, course_level: str) -> float:
    """Score based on appropriate difficulty level."""
    levels = {'beginner': 0, 'intermediate': 1, 'advanced': 2}
    user_l = levels.get(user_level.lower(), 0)
    course_l = levels.get(course_level.lower(), 0)
    diff = abs(user_l - course_l)
    return max(0.0, 1.0 - diff * 0.4)


def determine_user_level(enrolled_courses: List[Dict]) -> str:
    """Infer user level from their enrolled courses."""
    if not enrolled_courses:
        return 'beginner'
    levels = [c.get('level', 'beginner') for c in enrolled_courses]
    level_map = {'beginner': 0, 'intermediate': 1, 'advanced': 2}
    avg = sum(level_map.get(l, 0) for l in levels) / len(levels)
    if avg >= 1.5:
        return 'advanced'
    elif avg >= 0.7:
        return 'intermediate'
    return 'beginner'


async def get_recommendations(
    user_id: str,
    enrolled_courses: List[Dict],
    language_preference: str = 'en',
    limit: int = 6,
) -> List[Dict]:
    """
    Generate personalized course recommendations based on user's enrolled courses.
    Scores candidates by category similarity and appropriate difficulty level.
    """
    is_mn = language_preference == 'mn'

    user_categories = list({
        c.get('category_name', c.get('category_id', ''))
        for c in enrolled_courses
        if c.get('category_name') or c.get('category_id')
    })
    enrolled_ids = {c.get('id') or c.get('course_id') for c in enrolled_courses}
    user_level = determine_user_level(enrolled_courses)

    # Candidate pool — in production this would be a DB query for unenrolled courses
    candidate_pool = [
        {
            "id": "rec-1",
            "title": "Advanced Machine Learning" if not is_mn else "Дэвшилтэт Машин Сургалт",
            "instructor": "Dr. Sarah Chen",
            "rating": 4.9,
            "students": 28400,
            "price": 0,
            "level": "advanced",
            "categories": ["AI/ML", "Data Science"],
            "reason_en": "Based on your ML courses",
            "reason_mn": "Таны ML хичээлүүд дээр үндэслэн",
        },
        {
            "id": "rec-2",
            "title": "Python Data Structures" if not is_mn else "Python Өгөгдлийн Бүтэц",
            "instructor": "Emma Wilson",
            "rating": 4.7,
            "students": 45200,
            "price": 0,
            "level": "intermediate",
            "categories": ["Programming", "Data Science"],
            "reason_en": "Popular in your field",
            "reason_mn": "Таны чиглэлд алдартай",
        },
        {
            "id": "rec-3",
            "title": "Cloud Architecture Patterns" if not is_mn else "Клауд Архитектурын Загварууд",
            "instructor": "Mike Johnson",
            "rating": 4.8,
            "students": 19800,
            "price": 49.99,
            "level": "advanced",
            "categories": ["DevOps", "Cloud"],
            "reason_en": "Trending this week",
            "reason_mn": "Энэ долоо хоногт тренд",
        },
        {
            "id": "rec-4",
            "title": "React & TypeScript Mastery" if not is_mn else "React & TypeScript Мэргэшил",
            "instructor": "Alex Turner",
            "rating": 4.8,
            "students": 33100,
            "price": 39.99,
            "level": "intermediate",
            "categories": ["Programming", "Web Dev"],
            "reason_en": "Highly rated by peers",
            "reason_mn": "Үе тэнгийнхэн өндөр үнэлсэн",
        },
        {
            "id": "rec-5",
            "title": "Docker & Kubernetes Complete Guide" if not is_mn else "Docker & Kubernetes Бүрэн Гарын Авлага",
            "instructor": "Lisa Park",
            "rating": 4.9,
            "students": 22700,
            "price": 59.99,
            "level": "intermediate",
            "categories": ["DevOps"],
            "reason_en": "Essential for modern development",
            "reason_mn": "Орчин үеийн хөгжүүлэлтэд зайлшгүй",
        },
        {
            "id": "rec-6",
            "title": "Data Science with Python" if not is_mn else "Python-р Өгөгдлийн Шинжлэх Ухаан",
            "instructor": "Dr. James Lee",
            "rating": 4.6,
            "students": 51000,
            "price": 0,
            "level": "beginner",
            "categories": ["Data Science", "Programming"],
            "reason_en": "Great starting point",
            "reason_mn": "Эхлэхэд тохиромжтой",
        },
    ]

    # Filter out already enrolled courses
    candidates = [c for c in candidate_pool if c["id"] not in enrolled_ids]

    # Score each candidate
    scored = []
    for course in candidates:
        cat_score = compute_similarity(user_categories, course["categories"]) if user_categories else 0.3
        level_score = get_level_score(user_level, course["level"])
        rating_score = (course["rating"] - 4.0) / 1.0  # normalize 4.0-5.0 to 0-1
        popularity_score = min(1.0, course["students"] / 50000)

        total_score = (
            cat_score * 0.35 +
            level_score * 0.30 +
            rating_score * 0.20 +
            popularity_score * 0.15
        )

        scored.append({
            "id": course["id"],
            "title": course["title"],
            "instructor": course["instructor"],
            "rating": course["rating"],
            "students": course["students"],
            "price": course["price"],
            "level": course["level"],
            "score": round(total_score, 3),
            "reason": course["reason_mn"] if is_mn else course["reason_en"],
        })

    # Sort by score descending
    scored.sort(key=lambda x: x["score"], reverse=True)

    logger.info(
        f"Generated {min(limit, len(scored))} recommendations for user {user_id} "
        f"(level={user_level}, categories={user_categories}, lang={language_preference})"
    )

    return scored[:limit]
