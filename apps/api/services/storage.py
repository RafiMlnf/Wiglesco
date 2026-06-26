"""
WiggleAI — Storage Service
Phase 1: Save to local filesystem (apps/api/outputs/)
Phase 5+: Switch to Cloudflare R2 / AWS S3
"""
import asyncio
import shutil
from pathlib import Path

from loguru import logger
from core.config import settings


class StorageService:
    """
    Local filesystem storage for Phase 1 testing.
    Drop-in replacement: swap _upload_sync for S3 when going to production.
    """

    def __init__(self):
        self.output_dir = Path(settings.OUTPUT_DIR)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    async def upload(self, local_path: str, remote_key: str, content_type: str = None) -> str:
        """
        Phase 1: Copy file to output_dir and return a local file:// URL.
        Production: Replace with actual S3/R2 upload.
        """
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._save_local, local_path, remote_key)

    def _save_local(self, local_path: str, remote_key: str) -> str:
        """Copy temp file to persistent outputs/ directory."""
        dest = self.output_dir / remote_key.replace("/", "_")
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(local_path, dest)
        logger.info(f"💾 Saved locally: {dest}")
        return str(dest)  # Return absolute path as "URL" for Phase 1

    async def upload_bytes(self, data: bytes, remote_key: str, content_type: str = "application/octet-stream") -> str:
        """Save raw bytes locally."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._save_bytes_local, data, remote_key)

    def _save_bytes_local(self, data: bytes, remote_key: str) -> str:
        dest = self.output_dir / remote_key.replace("/", "_")
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest, "wb") as f:
            f.write(data)
        logger.info(f"💾 Saved bytes locally: {dest}")
        return str(dest)
