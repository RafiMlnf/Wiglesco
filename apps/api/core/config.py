"""
WiggleAI — Phase 1 Config (localhost testing, no DB/Redis/Stripe needed)
"""
import os
from pathlib import Path

# Base dir = apps/api/
BASE_DIR = Path(__file__).parent.parent

class Settings:
    # App
    APP_NAME: str = "WiggleAI"
    DEBUG: bool = True

    # AI Models
    MODEL_CACHE_DIR: str = str(BASE_DIR.parent.parent / "ml" / "models")
    DEVICE: str = "cuda"           # cuda | cpu
    MODEL_PRECISION: str = "fp16"

    # GTX 1650 (4GB VRAM) profile
    DEPTH_MODEL_SIZE: str = "Small"         # Small ~1.5GB, Base ~2.5GB
    USE_DIFFUSION_SYNTHESIS: bool = False   # SVD needs 10GB+
    USE_SDXL_INPAINT: bool = False          # SDXL needs 8GB+
    ESRGAN_TILE_SIZE: int = 256
    INPUT_MAX_LONG_SIDE: int = 1280

    # Processing
    MAX_FILE_SIZE_MB: int = 50
    MAX_IMAGE_DIMENSION: int = 1280
    MAX_FRAMES: int = 8
    DEFAULT_FRAMES: int = 4
    DEFAULT_EXPORT_FORMAT: str = "mp4"
    PROCESSING_TIMEOUT_SECONDS: int = 300

    # Storage (Phase 1: save locally, no cloud)
    OUTPUT_DIR: str = str(BASE_DIR / "outputs")
    S3_ENDPOINT_URL: str = ""
    S3_ACCESS_KEY_ID: str = ""
    S3_SECRET_ACCESS_KEY: str = ""
    S3_BUCKET_NAME: str = "wiggleai-media"
    S3_PUBLIC_URL: str = ""

    def __init__(self):
        # Load .env if exists
        env_path = BASE_DIR / ".env"
        if env_path.exists():
            from dotenv import load_dotenv
            load_dotenv(env_path)

        # Override from env
        self.DEVICE = os.getenv("DEVICE", self.DEVICE)
        self.DEPTH_MODEL_SIZE = os.getenv("DEPTH_MODEL_SIZE", self.DEPTH_MODEL_SIZE)
        self.USE_DIFFUSION_SYNTHESIS = os.getenv("USE_DIFFUSION_SYNTHESIS", "false").lower() == "true"
        self.USE_SDXL_INPAINT = os.getenv("USE_SDXL_INPAINT", "false").lower() == "true"
        self.MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", self.MODEL_CACHE_DIR)
        self.INPUT_MAX_LONG_SIDE = int(os.getenv("INPUT_MAX_LONG_SIDE", str(self.INPUT_MAX_LONG_SIDE)))
        self.ESRGAN_TILE_SIZE = int(os.getenv("ESRGAN_TILE_SIZE", str(self.ESRGAN_TILE_SIZE)))
        self.OUTPUT_DIR = os.getenv("OUTPUT_DIR", self.OUTPUT_DIR)

        # Ensure output dir exists
        Path(self.OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
        Path(self.MODEL_CACHE_DIR).mkdir(parents=True, exist_ok=True)


settings = Settings()
