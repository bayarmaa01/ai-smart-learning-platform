from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # App
    DEBUG: bool = False
    APP_NAME: str = "EduAI AI Service"
    VERSION: str = "1.0.0"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 4

    # Security
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:5000"]
    ALLOWED_HOSTS: List[str] = ["*"]
    API_KEY: str = ""

    # Redis
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_TTL: int = 3600

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/eduai_db"

    # AI Provider (openai | anthropic | local)
    AI_PROVIDER: str = "openai"
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4-turbo-preview"
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_MODEL: str = "claude-3-sonnet-20240229"

    # Local LLM (Ollama)
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    OLLAMA_MODEL: str = "llama3"

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    MAX_TOKENS: int = 2000
    MAX_HISTORY_MESSAGES: int = 20

    # Language Detection
    DEFAULT_LANGUAGE: str = "en"
    SUPPORTED_LANGUAGES: List[str] = ["en", "mn"]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
