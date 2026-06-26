"""WiggleAI — Storage Service (Cloudflare R2 / AWS S3 compatible)"""
import asyncio
import boto3
from botocore.config import Config
from pathlib import Path
from core.config import settings
from utils.logger import logger


class StorageService:
    def __init__(self):
        self._client = None

    def _get_client(self):
        if self._client is None:
            self._client = boto3.client(
                "s3",
                endpoint_url=settings.S3_ENDPOINT_URL or None,
                aws_access_key_id=settings.S3_ACCESS_KEY_ID,
                aws_secret_access_key=settings.S3_SECRET_ACCESS_KEY,
                config=Config(signature_version="s3v4"),
            )
        return self._client

    async def upload(self, local_path: str, remote_key: str, content_type: str = None) -> str:
        """Upload file to R2/S3 and return public URL."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._upload_sync, local_path, remote_key, content_type)

    def _upload_sync(self, local_path: str, remote_key: str, content_type: str = None) -> str:
        ext = Path(local_path).suffix.lower()
        ct_map = {".gif": "image/gif", ".webp": "image/webp", ".mp4": "video/mp4", ".png": "image/png"}
        content_type = content_type or ct_map.get(ext, "application/octet-stream")

        client = self._get_client()
        client.upload_file(
            local_path,
            settings.S3_BUCKET_NAME,
            remote_key,
            ExtraArgs={"ContentType": content_type, "ACL": "public-read"},
        )

        if settings.S3_PUBLIC_URL:
            return f"{settings.S3_PUBLIC_URL}/{remote_key}"
        return f"https://{settings.S3_BUCKET_NAME}.r2.cloudflarestorage.com/{remote_key}"

    async def upload_bytes(self, data: bytes, remote_key: str, content_type: str = "application/octet-stream") -> str:
        """Upload raw bytes to storage."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._upload_bytes_sync, data, remote_key, content_type)

    def _upload_bytes_sync(self, data: bytes, remote_key: str, content_type: str) -> str:
        import io
        client = self._get_client()
        client.put_object(
            Bucket=settings.S3_BUCKET_NAME,
            Key=remote_key,
            Body=io.BytesIO(data),
            ContentType=content_type,
        )
        if settings.S3_PUBLIC_URL:
            return f"{settings.S3_PUBLIC_URL}/{remote_key}"
        return f"https://{settings.S3_BUCKET_NAME}.r2.cloudflarestorage.com/{remote_key}"
