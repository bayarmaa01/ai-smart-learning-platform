"""
LLM Service - Supports OpenAI, Anthropic, and local Ollama
Automatically selects provider based on configuration
"""

import logging
from typing import List, Dict, Optional
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import settings

logger = logging.getLogger(__name__)


class LLMMessage:
    def __init__(self, role: str, content: str):
        self.role = role
        self.content = content

    def to_dict(self) -> Dict:
        return {"role": self.role, "content": self.content}


class LLMResponse:
    def __init__(self, content: str, tokens_used: int = 0, model: str = ""):
        self.content = content
        self.tokens_used = tokens_used
        self.model = model


class OpenAIProvider:
    def __init__(self):
        from openai import AsyncOpenAI
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        self.model = settings.OPENAI_MODEL

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def generate(
        self,
        messages: List[LLMMessage],
        system_prompt: str,
        max_tokens: int = 1000,
        temperature: float = 0.7,
    ) -> LLMResponse:
        all_messages = [{"role": "system", "content": system_prompt}]
        all_messages.extend([m.to_dict() for m in messages])

        response = await self.client.chat.completions.create(
            model=self.model,
            messages=all_messages,
            max_tokens=max_tokens,
            temperature=temperature,
        )

        return LLMResponse(
            content=response.choices[0].message.content,
            tokens_used=response.usage.total_tokens,
            model=self.model,
        )


class AnthropicProvider:
    def __init__(self):
        import anthropic
        self.client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
        self.model = settings.ANTHROPIC_MODEL

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def generate(
        self,
        messages: List[LLMMessage],
        system_prompt: str,
        max_tokens: int = 1000,
        temperature: float = 0.7,
    ) -> LLMResponse:
        response = await self.client.messages.create(
            model=self.model,
            system=system_prompt,
            messages=[m.to_dict() for m in messages],
            max_tokens=max_tokens,
        )

        return LLMResponse(
            content=response.content[0].text,
            tokens_used=response.usage.input_tokens + response.usage.output_tokens,
            model=self.model,
        )


class OllamaProvider:
    """Local LLM via Ollama - free, privacy-preserving option"""

    def __init__(self):
        import httpx
        self.base_url = settings.OLLAMA_BASE_URL
        self.model = settings.OLLAMA_MODEL
        self.client = httpx.AsyncClient(timeout=60.0)

    async def generate(
        self,
        messages: List[LLMMessage],
        system_prompt: str,
        max_tokens: int = 1000,
        temperature: float = 0.7,
    ) -> LLMResponse:
        all_messages = [{"role": "system", "content": system_prompt}]
        all_messages.extend([m.to_dict() for m in messages])

        response = await self.client.post(
            f"{self.base_url}/api/chat",
            json={
                "model": self.model,
                "messages": all_messages,
                "stream": False,
                "options": {"temperature": temperature, "num_predict": max_tokens},
            },
        )
        response.raise_for_status()
        data = response.json()

        return LLMResponse(
            content=data["message"]["content"],
            tokens_used=data.get("eval_count", 0),
            model=self.model,
        )


class MockProvider:
    """Fallback mock provider for development/testing"""

    async def generate(
        self,
        messages: List[LLMMessage],
        system_prompt: str,
        max_tokens: int = 1000,
        temperature: float = 0.7,
    ) -> LLMResponse:
        last_message = messages[-1].content if messages else ""
        is_mongolian = any(ord(c) > 0x0400 for c in last_message)

        if is_mongolian:
            response = (
                f"Таны асуултад хариулж байна: **{last_message[:50]}...**\n\n"
                "Энэ бол туршилтын хариулт юм. Бодит AI үйлчилгээг ашиглахын тулд "
                "OpenAI эсвэл Anthropic API түлхүүрийг тохируулна уу.\n\n"
                "**Санал болгох хичээлүүд:**\n"
                "- Machine Learning үндэс\n"
                "- Python програмчлал\n"
                "- Өгөгдлийн шинжлэх ухаан"
            )
        else:
            response = (
                f"Responding to your query: **{last_message[:50]}...**\n\n"
                "This is a mock response. Configure OpenAI or Anthropic API keys for real AI responses.\n\n"
                "**Recommended courses:**\n"
                "- Machine Learning Fundamentals\n"
                "- Python Programming\n"
                "- Data Science Essentials"
            )

        return LLMResponse(content=response, tokens_used=50, model="mock")


def get_llm_provider():
    """Factory function to get the configured LLM provider."""
    provider = settings.AI_PROVIDER.lower()

    if provider == "openai" and settings.OPENAI_API_KEY:
        logger.info("Using OpenAI provider")
        return OpenAIProvider()
    elif provider == "anthropic" and settings.ANTHROPIC_API_KEY:
        logger.info("Using Anthropic provider")
        return AnthropicProvider()
    elif provider == "ollama":
        logger.info("Using Ollama (local) provider")
        return OllamaProvider()
    else:
        logger.warning("No AI provider configured, using mock provider")
        return MockProvider()


_llm_provider = None


def get_provider():
    global _llm_provider
    if _llm_provider is None:
        _llm_provider = get_llm_provider()
    return _llm_provider
