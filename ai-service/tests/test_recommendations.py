import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch
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
        mock.incr = AsyncMock(return_value=1)
        yield mock


class TestRecommendationsEndpoint:
    def test_get_recommendations_english(self):
        response = client.get(
            "/recommendations/test-user-123",
            params={"language": "en"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "recommendations" in data
        assert isinstance(data["recommendations"], list)
        assert len(data["recommendations"]) > 0

    def test_get_recommendations_mongolian(self):
        response = client.get(
            "/recommendations/test-user-123",
            params={"language": "mn"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "recommendations" in data
        assert isinstance(data["recommendations"], list)

    def test_recommendations_have_required_fields(self):
        response = client.get(
            "/recommendations/test-user-123",
            params={"language": "en"},
        )
        assert response.status_code == 200
        data = response.json()
        for rec in data["recommendations"]:
            assert "id" in rec
            assert "title" in rec
            assert "description" in rec
            assert "level" in rec
            assert "score" in rec

    def test_recommendations_default_language(self):
        response = client.get("/recommendations/test-user-123")
        assert response.status_code == 200

    def test_recommendations_invalid_language_fallback(self):
        response = client.get(
            "/recommendations/test-user-123",
            params={"language": "fr"},
        )
        assert response.status_code == 200
