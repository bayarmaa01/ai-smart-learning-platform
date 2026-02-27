import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.language_detector import LanguageDetector


class TestLanguageDetector:
    def setup_method(self):
        self.detector = LanguageDetector()

    def test_detect_english_text(self):
        texts = [
            "Hello, how are you today?",
            "What is machine learning?",
            "I want to learn programming",
            "This is an English sentence",
            "The quick brown fox jumps over the lazy dog",
        ]
        for text in texts:
            result = self.detector.detect(text)
            assert result == "en", f"Expected 'en' for: {text}, got: {result}"

    def test_detect_mongolian_text(self):
        texts = [
            "Сайн байна уу?",
            "Машин сургалт гэж юу вэ?",
            "Би программчлал сурахыг хүсч байна",
            "Монгол хэл дээр бичих",
            "Өдрийн мэнд",
        ]
        for text in texts:
            result = self.detector.detect(text)
            assert result == "mn", f"Expected 'mn' for: {text}, got: {result}"

    def test_detect_mongolian_by_cyrillic_script(self):
        result = self.detector.detect("Монгол")
        assert result == "mn"

    def test_detect_english_fallback(self):
        result = self.detector.detect("12345")
        assert result in ["en", "mn"]

    def test_get_system_prompt_english(self):
        prompt = self.detector.get_system_prompt("en")
        assert isinstance(prompt, str)
        assert len(prompt) > 0
        assert "English" in prompt or "english" in prompt.lower()

    def test_get_system_prompt_mongolian(self):
        prompt = self.detector.get_system_prompt("mn")
        assert isinstance(prompt, str)
        assert len(prompt) > 0

    def test_detect_empty_string(self):
        result = self.detector.detect("")
        assert result in ["en", "mn"]

    def test_detect_mixed_language(self):
        result = self.detector.detect("Hello Сайн байна уу")
        assert result in ["en", "mn"]
