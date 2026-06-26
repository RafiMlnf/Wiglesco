"""WiggleAI — Health Check Router"""
from fastapi import APIRouter
from pydantic import BaseModel
import redis
from core.config import settings

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    version: str
    database: str
    redis: str
    gpu: str


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Full health check including dependencies."""
    db_status = "ok"
    redis_status = "ok"
    gpu_status = "unknown"

    # Check Redis
    try:
        r = redis.from_url(settings.REDIS_URL)
        r.ping()
    except Exception:
        redis_status = "error"

    # Check GPU
    try:
        import torch
        gpu_status = f"cuda:{torch.cuda.get_device_name(0)}" if torch.cuda.is_available() else "cpu"
    except Exception:
        gpu_status = "unavailable"

    return HealthResponse(
        status="ok",
        version=settings.APP_VERSION,
        database=db_status,
        redis=redis_status,
        gpu=gpu_status,
    )


@router.get("/")
async def root():
    return {"message": "WiggleAI API", "docs": "/docs"}
