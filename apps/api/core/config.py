"""
WiggleAI — Application Configuration
"""
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # App
    APP_NAME: str = "WiggleAI API"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "development"  # development | staging | production

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Security
    SECRET_KEY: str = "change-me-in-production-use-openssl-rand-hex-32"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "https://wiggleai.app",
    ]

    # Database (PostgreSQL)
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/wiggleai"
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    # Storage (Cloudflare R2 / S3-compatible)
    S3_ENDPOINT_URL: str = ""
    S3_ACCESS_KEY_ID: str = ""
    S3_SECRET_ACCESS_KEY: str = ""
    S3_BUCKET_NAME: str = "wiggleai-media"
    S3_PUBLIC_URL: str = ""

    # AI Models
    MODEL_CACHE_DIR: str = "./ml/models"
    DEVICE: str = "cuda"  # cuda | cpu | mps
    MODEL_PRECISION: str = "fp16"  # fp16 | fp32 | int8

    # ── GTX 1650 / Low-VRAM Mode (4GB) ───────────────────────
    # Depth model: Small fits in ~1.5GB, Base needs ~2.5GB, Large needs ~6GB
    # SVD (novel view diffusion) needs 10GB+ — disabled for 1650, uses classical warp
    # SDXL Inpaint needs 8GB+ — disabled for 1650, uses edge-extend fill
    DEPTH_MODEL_SIZE: str = "Small"        # Small | Base | Large
    USE_DIFFUSION_SYNTHESIS: bool = False  # Set True only on 10GB+ VRAM
    USE_SDXL_INPAINT: bool = False         # Set True only on 8GB+ VRAM
    ESRGAN_TILE_SIZE: int = 256            # Smaller tile = less VRAM (256 for 4GB)
    INPUT_MAX_LONG_SIDE: int = 1280        # Resize input before inference (1280 safe for 4GB)

    # Processing Limits
    MAX_FILE_SIZE_MB: int = 50
    MAX_IMAGE_DIMENSION: int = 1280        # Hard cap for 4GB VRAM safety
    MAX_FRAMES: int = 8
    DEFAULT_FRAMES: int = 4
    DEFAULT_EXPORT_FORMAT: str = "mp4"     # gif | webp | mp4 | lenticular
    PROCESSING_TIMEOUT_SECONDS: int = 300

    # Rate Limiting
    RATE_LIMIT_FREE: str = "5/hour"
    RATE_LIMIT_PRO: str = "100/day"
    RATE_LIMIT_STUDIO: str = "1000/day"

    # Sentry
    SENTRY_DSN: str = ""

    # Stripe
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_PRICE_PRO: str = ""
    STRIPE_PRICE_STUDIO: str = ""


settings = Settings()
