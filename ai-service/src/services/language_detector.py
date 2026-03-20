"""
Multilingual language detection service
Supports English (en) and Mongolian (mn)
"""

import re
import logging
from typing import Tuple

logger = logging.getLogger(__name__)

# Mongolian Unicode range: U+1800–U+18AF (Traditional), U+0400–U+04FF (Cyrillic used in modern Mongolian)
MONGOLIAN_CYRILLIC_PATTERN = re.compile(r"[\u0400-\u04FF\u1800-\u18AF]")

# Common Mongolian words in Cyrillic script
MONGOLIAN_KEYWORDS = {
    "байна",
    "юу",
    "хэрхэн",
    "яаж",
    "ямар",
    "хэн",
    "хаана",
    "хэзээ",
    "болно",
    "болохгүй",
    "тийм",
    "үгүй",
    "би",
    "та",
    "тэр",
    "бид",
    "сайн",
    "муу",
    "их",
    "бага",
    "өдөр",
    "шөнө",
    "өнөөдөр",
    "маргааш",
    "сурах",
    "заах",
    "хичээл",
    "ном",
    "сургууль",
    "багш",
    "оюутан",
    "асуулт",
    "хариулт",
    "тусламж",
    "мэдээлэл",
    "тайлбар",
}


def detect_language(text: str) -> Tuple[str, float]:
    """
    Detect language of input text.
    Returns (language_code, confidence) tuple.
    Supports: 'en' (English), 'mn' (Mongolian)
    """
    if not text or not text.strip():
        return "en", 0.5

    text_lower = text.lower().strip()

    # Count Mongolian Cyrillic characters
    mongolian_chars = len(MONGOLIAN_CYRILLIC_PATTERN.findall(text))
    total_chars = len([c for c in text if c.isalpha()])

    if total_chars == 0:
        return "en", 0.5

    mongolian_ratio = mongolian_chars / total_chars

    # Check for Mongolian keywords
    words = set(text_lower.split())
    mongolian_keyword_count = len(words.intersection(MONGOLIAN_KEYWORDS))

    # Decision logic
    if mongolian_ratio > 0.3 or mongolian_keyword_count >= 2:
        confidence = min(
            0.95, 0.5 + mongolian_ratio * 0.5 + mongolian_keyword_count * 0.1
        )
        return "mn", confidence

    if mongolian_ratio > 0.1 or mongolian_keyword_count >= 1:
        return "mn", 0.65

    # Try langdetect as fallback
    try:
        from langdetect import detect, DetectorFactory

        DetectorFactory.seed = 42
        detected = detect(text)
        if detected == "mn" or detected == "mo":
            return "mn", 0.8
        return "en", 0.85
    except Exception:
        pass

    return "en", 0.8


def get_system_prompt(language: str, context: dict = None) -> str:
    """Generate system prompt based on detected language."""
    base_context = ""
    if context:
        if context.get("user_role") == "student":
            base_context = " You are helping a student learn."
        elif context.get("user_role") == "instructor":
            base_context = " You are assisting an instructor."

    if language == "mn":
        return f"""Та EduAI суралцахуйн платформын AI туслагч юм.{base_context}
Монгол хэлээр тодорхой, найрсаг, мэдлэгтэй хариулт өгнө үү.
Хэрэв асуулт нь хичээл, технологи, эсвэл суралцахуйтай холбоотой бол дэлгэрэнгүй тайлбарлана уу.
Хариултаа Монгол хэлээр өгнө үү. Markdown форматыг ашиглаж болно."""
    else:
        return f"""You are an AI learning assistant for EduAI Platform.{base_context}
Provide clear, friendly, and knowledgeable responses in English.
For questions about courses, technology, or learning topics, give detailed explanations.
Use markdown formatting when appropriate for better readability."""


class LanguageDetector:
    """Wrapper class for language detection functions."""

    def detect(self, text: str) -> str:
        """Detect language and return only the language code."""
        language, _ = detect_language(text)
        return language

    def get_system_prompt(self, language: str, context: dict = None) -> str:
        """Get system prompt for the detected language."""
        return get_system_prompt(language, context)
