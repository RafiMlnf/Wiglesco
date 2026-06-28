"""
WiggleAI — Celery Task Definitions
Background job processing for AI pipeline
"""
from celery import Celery
from celery.utils.log import get_task_logger
import asyncio

from core.config import settings

logger = get_task_logger(__name__)

# ── Celery App ──────────────────────────────────────────────────
celery_app = Celery(
    "wiggleai",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,  # Process 1 task at a time (GPU contention)
    task_soft_time_limit=settings.PROCESSING_TIMEOUT_SECONDS,
    task_time_limit=settings.PROCESSING_TIMEOUT_SECONDS + 60,
    result_expires=3600 * 24,  # Keep results for 24h
)


@celery_app.task(
    bind=True,
    name="tasks.process_image",
    max_retries=2,
    default_retry_delay=30,
    track_started=True,
)
def process_image_task(
    self,
    job_id: str,
    input_image_url: str,
    num_frames: int = 4,
    parallax_strength: float = 0.5,
    effect_style: str = "normal",
    export_format: str = "mp4",
    fps: int = 15,
):
    """
    Main Celery task: download image → run AI pipeline → save results.
    
    This task runs in a Celery worker with GPU access.
    Progress is broadcast to Redis pub/sub for WebSocket delivery.
    """
    import redis
    import json
    import tempfile
    import httpx

    r = redis.from_url(settings.REDIS_URL)
    channel = f"job:{job_id}:progress"

    def broadcast(step: str, display: str, progress: float):
        """Publish progress to Redis channel for WebSocket pickup."""
        message = json.dumps({
            "job_id": job_id,
            "step": step,
            "display": display,
            "progress": progress,
        })
        r.publish(channel, message)
        r.setex(f"job:{job_id}:status", 3600, message)
        logger.info(f"[{job_id}] {display} ({progress:.1f}%)")

        # Update Celery task state
        self.update_state(
            state="PROGRESS",
            meta={"step": step, "progress": progress}
        )

    async def _run():
        # Download input image
        broadcast("download", "⬇️ Downloading image...", 2.0)
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp_path = tmp.name

        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.get(input_image_url)
            resp.raise_for_status()
            with open(tmp_path, "wb") as f:
                f.write(resp.content)

        # Run pipeline
        from services.ai_pipeline import AIPipeline
        pipeline = AIPipeline()
        await pipeline.initialize()

        async def progress_callback(step, display, progress):
            broadcast(step, display, progress)

        result = await pipeline.run(
            image_path=tmp_path,
            job_id=job_id,
            num_frames=num_frames,
            parallax_strength=parallax_strength,
            effect_style=effect_style,
            export_format=export_format,
            fps=fps,
            progress_callback=progress_callback,
        )

        # Cleanup
        import os
        os.unlink(tmp_path)

        return result

    try:
        # Run async pipeline in sync Celery task
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(_run())
        loop.close()

        broadcast("done", "✅ Processing complete!", 100.0)

        # Update database
        _update_job_completed(job_id, result)

        return result

    except Exception as exc:
        error_msg = str(exc)
        logger.error(f"Job {job_id} failed: {error_msg}")
        broadcast("error", f"❌ Error: {error_msg}", -1)
        _update_job_failed(job_id, error_msg)

        raise self.retry(exc=exc)


def _update_job_completed(job_id: str, result: dict):
    """Synchronously update job status in database after completion."""
    # NOTE: This uses a sync psycopg2 connection to avoid async complexity in Celery
    import psycopg2
    from urllib.parse import urlparse

    db_url = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE processing_jobs SET
            status = 'completed',
            progress = 100.0,
            output_url = %s,
            depth_map_url = %s,
            thumbnail_url = %s,
            processing_time_seconds = %s,
            completed_at = NOW()
        WHERE id = %s
        """,
        (
            result["output_url"],
            result["depth_map_url"],
            result["thumbnail_url"],
            result["processing_time"],
            job_id,
        )
    )
    conn.commit()
    cur.close()
    conn.close()


def _update_job_failed(job_id: str, error_message: str):
    """Update job status to failed in database."""
    import psycopg2
    db_url = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    cur.execute(
        "UPDATE processing_jobs SET status = 'failed', error_message = %s WHERE id = %s",
        (error_message, job_id)
    )
    conn.commit()
    cur.close()
    conn.close()
