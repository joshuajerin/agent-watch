"""Agent runner — forwards query to AI provider and streams response chunks."""

import logging
from collections.abc import AsyncGenerator

from config import settings

logger = logging.getLogger(__name__)


async def run_agent(query: str) -> AsyncGenerator[str, None]:
    """Stream response chunks from the configured AI provider."""
    provider = settings.ai_provider.lower()

    if provider == "anthropic":
        async for chunk in _run_anthropic(query):
            yield chunk
    else:
        raise ValueError(f"Unknown AI provider: {provider}. Set AI_PROVIDER=anthropic in .env")


async def _run_anthropic(query: str) -> AsyncGenerator[str, None]:
    """Stream from Anthropic API using the official SDK."""
    try:
        import anthropic
    except ImportError:
        raise RuntimeError("anthropic package not installed. Run: pip install anthropic")

    if not settings.anthropic_api_key:
        raise RuntimeError("ANTHROPIC_API_KEY not set in .env")

    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    async with client.messages.stream(
        model=settings.ai_model,
        max_tokens=settings.max_tokens,
        messages=[{"role": "user", "content": query}],
    ) as stream:
        async for text in stream.text_stream:
            yield text
