"""Pydantic settings loaded from environment / .env file."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Auth
    auth_token: str = ""

    # AI
    anthropic_api_key: str = ""
    ai_model: str = "claude-haiku-4-5-20251001"
    ai_provider: str = "anthropic"
    max_tokens: int = 2048

    # Server
    log_level: str = "INFO"
    rate_limit_qpm: int = 20


settings = Settings()
