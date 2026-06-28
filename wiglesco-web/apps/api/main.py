"""
WiggleAI — FastAPI Application (Direct Local Mode)
A simple, robust backend that runs entirely in-process on localhost.
No Docker, Redis, Celery, Postgres, or Auth required.
"""
import uuid
import shutil
import time
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from loguru import logger

from pillow_heif import register_heif_opener
register_heif_opener()

from core.config import settings
from services.ai_pipeline import AIPipeline

app = FastAPI(
    title="Wiglesco API (Local Direct)",
    description="Local version of Wiglesco running directly in-process",
    version="0.1.0",
)

# Enable CORS for localhost frontend development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global pipeline instance
pipeline = AIPipeline()

@app.on_event("startup")
async def startup():
    logger.info("Initializing local AI pipeline...")
    # Initialize all models (downloads Depth-Anything-V2-Small on first run)
    await pipeline.initialize()
    logger.info("Local Wiglesco pipeline initialized and ready.")

# Ensure directories exist
Path(settings.OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
# Mount static files so generated MP4s and Depth Maps are served directly
app.mount("/outputs", StaticFiles(directory=settings.OUTPUT_DIR), name="outputs")

class ProcessResponse(BaseModel):
    status: str
    output_url: str
    depth_map_url: str
    thumbnail_url: str
    processing_time: float

@app.post("/api/v1/process/direct", response_model=ProcessResponse)
async def process_direct(
    file: UploadFile = File(...),
    num_frames: int = Form(default=4, ge=3, le=8),
    parallax_strength: float = Form(default=0.5, ge=0.1, le=1.0),
    effect_style: str = Form(default="normal"),
    export_format: str = Form(default="mp4"),
    fps: int = Form(default=15, ge=6, le=30),
):
    """
    Direct synchronous endpoint for local GUI testing.
    Uploads file -> Runs full pipeline -> Saves output -> Returns direct URLs.
    """
    allowed_types = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]
    file_ext = Path(file.filename).suffix.lower() if file.filename else ""
    if file.content_type not in allowed_types and file_ext not in [".heic", ".heif"]:
        raise HTTPException(status_code=400, detail="Invalid file format. Use JPEG, PNG, WebP, or HEIC.")

    job_id = str(uuid.uuid4())
    logger.info(f"Processing local job {job_id} ({file.filename})")

    # Create temporary directory for processing input
    temp_dir = Path(settings.OUTPUT_DIR) / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_input_path = temp_dir / f"{job_id}_{file.filename}"

    try:
        # Save uploaded file to temp path
        with open(temp_input_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Run pipeline
        # Our modified local StorageService saves files directly to settings.OUTPUT_DIR
        # and returns their absolute local paths as output_url, depth_map_url, etc.
        result = await pipeline.run(
            image_path=str(temp_input_path),
            job_id=job_id,
            num_frames=num_frames,
            parallax_strength=parallax_strength,
            effect_style=effect_style,
            export_format=export_format,
            fps=fps,
        )

        # Convert local absolute paths from StorageService to browser-accessible static URLs
        # StorageService saves files as settings.OUTPUT_DIR / remote_key.replace("/", "_")
        # e.g., output path: D:\Coding\Stereogram\apps\api\outputs\jobs_{job_id}_output.mp4
        output_filename = f"jobs_{job_id}_output.{export_format}"
        depth_filename = f"jobs_{job_id}_depth_map.png"
        thumbnail_filename = f"jobs_{job_id}_thumbnail.webp"

        base_url = "http://localhost:8000/outputs"
        
        return ProcessResponse(
            status="success",
            output_url=f"{base_url}/{output_filename}",
            depth_map_url=f"{base_url}/{depth_filename}",
            thumbnail_url=f"{base_url}/{thumbnail_filename}",
            processing_time=result["processing_time"],
        )

    except Exception as e:
        logger.exception(f"Error during direct local process: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup temporary input file
        if temp_input_path.exists():
            temp_input_path.unlink()

@app.get("/")
async def root():
    return {"message": "Wiglesco Direct Local API is running", "docs": "/docs"}
