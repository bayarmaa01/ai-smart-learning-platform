import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, MagicMock, patch
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def mock_redis():
    with patch("app.core.redis_client.redis_client") as mock:
        mock.get = AsyncMock(return_value=None)
        mock.set = AsyncMock(return_value=True)
        mock.delete = AsyncMock(return_value=1)
        mock.expire = AsyncMock(return_value=True)
        mock.incr = AsyncMock(return_value=1)
        yield mock


@pytest.fixture(autouse=True)
def mock_llm():
    with patch("app.services.llm_service.LLMService.generate_response") as mock:
        mock.return_value = "This is a test AI response."
        yield mock


class TestChatEndpoint:
    def test_chat_english_message(self):
        response = client.post(
            "/chat",
            json={
                "message": "What is machine learning?",
                "user_id": "test-user-123",
                "session_id": "test-session-456",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "detected_language" in data
        assert data["detected_language"] == "en"

    def test_chat_mongolian_message(self):
        response = client.post(
            "/chat",
            json={
                "message": "Машин сургалт гэж юу вэ?",
                "user_id": "test-user-123",
                "session_id": "test-session-456",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "detected_language" in data
        assert data["detected_language"] == "mn"

    def test_chat_missing_message(self):
        response = client.post(
            "/chat",
            json={
                "user_id": "test-user-123",
            },
        )
        assert response.status_code == 422

    def test_chat_empty_message(self):
        response = client.post(
            "/chat",
            json={
                "message": "",
                "user_id": "test-user-123",
            },
        )
        assert response.status_code == 422

    def test_chat_message_too_long(self):
        response = client.post(
            "/chat",
            json={
                "message": "x" * 5001,
                "user_id": "test-user-123",
            },
        )
        assert response.status_code == 422

    def test_get_chat_history(self):
        with patch("app.services.chat_service.ChatService.get_history") as mock:
            mock.return_value = [
                {
                    "role": "user",
                    "content": "Hello",
                    "timestamp": "2024-01-01T00:00:00",
                    "language": "en",
                }
            ]
            response = client.get(
                "/chat/history/test-user-123",
                params={"session_id": "test-session-456"},
            )
            assert response.status_code == 200
            data = response.json()
            assert "history" in data
            assert isinstance(data["history"], list)

    def test_clear_chat_history(self):
        with patch("app.services.chat_service.ChatService.clear_history") as mock:
            mock.return_value = True
            response = client.delete(
                "/chat/history/test-user-123",
                params={"session_id": "test-session-456"},
            )
            assert response.status_code == 200


class TestHealthEndpoint:
    def test_health_check(self):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert data["status"] in ["healthy", "degraded"]

    def test_readiness_check(self):
        response = client.get("/health/ready")
        assert response.status_code in [200, 503]

    def test_liveness_check(self):
        response = client.get("/health/live")
        assert response.status_code == 200
