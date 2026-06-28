"""
WiggleAI — Processing Router
Handles: Job submission, status, WebSocket progress, cancellation
"""
import json
import uuid
from datetime import datetime

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from loguru import logger
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.database import get_db
from models.db_models import ExportFormat, EffectStyle, JobStatus, ProcessingJob, Project
from workers.tasks import process_image_task

router = APIRouter()


class JobCreateResponse(BaseModel):
    job_id: str
    project_id: str
    status: str
    message: str


class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    progress: float
    current_step: str | None
    output_url: str | None
    thumbnail_url: str | None
    depth_map_url: str | None
    processing_time: float | None
    error_message: str | None
    created_at: datetime
    completed_at: datetime | None


@router.post("/submit", response_model=JobCreateResponse)
async def submit_job(
    file: UploadFile = File(...),
    num_frames: int = Form(default=4, ge=3, le=8),
    parallax_strength: float = Form(default=0.5, ge=0.1, le=1.0),
    effect_style: str = Form(default="normal"),
    export_format: str = Form(default="mp4"),
    fps: int = Form(default=15, ge=6, le=30),
    db: AsyncSession = Depends(get_db),
    # current_user: User = Depends(get_current_user),  # Uncomment when auth is ready
):
    """
    Submit a new image processing job.
    
    1. Validates and uploads the input image to storage
    2. Creates Project + ProcessingJob records in DB
    3. Dispatches Celery task
    4. Returns job_id for status polling / WebSocket
    """
    # Validate file
    if file.content_type not in ["image/jpeg", "image/png", "image/webp"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Use JPEG, PNG, or WebP.")

    content = await file.read()
    size_mb = len(content) / (1024 * 1024)
    if size_mb > settings.MAX_FILE_SIZE_MB:
        raise HTTPException(status_code=413, detail=f"File too large. Max {settings.MAX_FILE_SIZE_MB}MB.")

    # TODO: Upload to R2 storage
    # input_url = await storage_service.upload_bytes(content, f"inputs/{uuid.uuid4()}/{file.filename}")
    input_url = f"https://placeholder.wiggleai.app/inputs/{uuid.uuid4()}"

    # Create DB records
    project_id = uuid.uuid4()
    job_id = uuid.uuid4()

    project = Project(
        id=project_id,
        user_id=uuid.uuid4(),  # Replace with current_user.id
        title=file.filename or "Untitled",
    )
    db.add(project)

    job = ProcessingJob(
        id=job_id,
        project_id=project_id,
        input_image_url=input_url,
        input_filename=file.filename or "image.jpg",
        num_frames=num_frames,
        parallax_strength=parallax_strength,
        effect_style=EffectStyle(effect_style),
        export_format=ExportFormat(export_format),
        fps=fps,
        status=JobStatus.PENDING,
    )
    db.add(job)
    await db.flush()

    # Dispatch Celery task
    celery_task = process_image_task.apply_async(
        kwargs={
            "job_id": str(job_id),
            "input_image_url": input_url,
            "num_frames": num_frames,
            "parallax_strength": parallax_strength,
            "effect_style": effect_style,
            "export_format": export_format,
            "fps": fps,
        },
        task_id=str(job_id),
    )

    job.celery_task_id = celery_task.id
    job.status = JobStatus.PROCESSING

    logger.info(f"Job {job_id} dispatched to Celery")

    return JobCreateResponse(
        job_id=str(job_id),
        project_id=str(project_id),
        status="processing",
        message="Job submitted successfully. Connect to WebSocket for real-time progress.",
    )


@router.get("/{job_id}/status", response_model=JobStatusResponse)
async def get_job_status(job_id: str, db: AsyncSession = Depends(get_db)):
    """Poll job status (fallback when WebSocket is unavailable)."""
    from sqlalchemy import select
    result = await db.execute(select(ProcessingJob).where(ProcessingJob.id == uuid.UUID(job_id)))
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    return JobStatusResponse(
        job_id=str(job.id),
        status=job.status.value,
        progress=job.progress,
        current_step=job.current_step,
        output_url=job.output_url,
        thumbnail_url=job.thumbnail_url,
        depth_map_url=job.depth_map_url,
        processing_time=job.processing_time_seconds,
        error_message=job.error_message,
        created_at=job.created_at,
        completed_at=job.completed_at,
    )


@router.websocket("/{job_id}/ws")
async def job_progress_websocket(websocket: WebSocket, job_id: str):
    """
    Real-time progress via WebSocket.
    Subscribes to Redis pub/sub channel: job:{job_id}:progress
    """
    await websocket.accept()
    redis_client = aioredis.from_url(settings.REDIS_URL)

    try:
        # Send cached status immediately if available
        cached = await redis_client.get(f"job:{job_id}:status")
        if cached:
            await websocket.send_text(cached.decode())

        # Subscribe to live updates
        pubsub = redis_client.pubsub()
        await pubsub.subscribe(f"job:{job_id}:progress")

        async for message in pubsub.listen():
            if message["type"] == "message":
                data = message["data"].decode()
                await websocket.send_text(data)

                # Close connection when done
                parsed = json.loads(data)
                if parsed.get("step") in ("done", "error"):
                    break

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for job {job_id}")
    except Exception as e:
        logger.error(f"WebSocket error for job {job_id}: {e}")
    finally:
        await pubsub.unsubscribe()
        await redis_client.aclose()
        await websocket.close()


@router.delete("/{job_id}/cancel")
async def cancel_job(job_id: str, db: AsyncSession = Depends(get_db)):
    """Cancel a pending or processing job."""
    from celery.result import AsyncResult
    task = AsyncResult(job_id)
    task.revoke(terminate=True, signal="SIGKILL")

    from sqlalchemy import select, update
    await db.execute(
        update(ProcessingJob)
        .where(ProcessingJob.id == uuid.UUID(job_id))
        .values(status=JobStatus.CANCELLED)
    )

    return {"message": f"Job {job_id} cancelled"}
