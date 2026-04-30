"""
Application configuration using environment variables.
"""

import os
from functools import lru_cache
from pydantic_settings import BaseSettings
from pydantic import Field
from dotenv import load_dotenv

load_dotenv()


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Supabase
    supabase_url: str = Field(
        default="",
        description="Supabase project URL"
    )
    supabase_key: str = Field(
        default="",
        description="Supabase service role key"
    )

    # Firebase
    firebase_credentials_json: str = Field(
        default="",
        description="Path to Firebase Admin SDK credentials JSON file"
    )

    # Gemini AI
    gemini_api_key: str = Field(
        default="",
        description="Google Gemini API key for LLM fallback parsing"
    )

    # Tesseract
    tesseract_cmd: str = Field(
        default="",
        description="Path to Tesseract executable"
    )

    # App settings
    app_name: str = "GPay Transaction Extractor"
    debug: bool = Field(default=False)
    cors_origins: str = Field(
        default="*",
        description="Comma-separated list of allowed CORS origins"
    )

    # Razorpay
    razorpay_key: str = Field(
        default="",
        description="Razorpay API Key ID"
    )
    razorpay_secret: str = Field(
        default="",
        description="Razorpay API Key Secret"
    )

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

    def get_cors_origins(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        if self.cors_origins == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",")]


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
