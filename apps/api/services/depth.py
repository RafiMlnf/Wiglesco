"""
WiggleAI — Depth Estimation Service
Using: Depth Anything V2 (ViT-Large) via HuggingFace Transformers
"""
import asyncio
from functools import lru_cache
from typing import Optional

import numpy as np
import torch
from PIL import Image
from loguru import logger
from transformers import pipeline as hf_pipeline

from core.config import settings


class DepthEstimationService:
    """
    Wraps Depth Anything V2 for monocular depth estimation.

    Models available (trade-off: accuracy vs speed):
      - depth-anything/Depth-Anything-V2-Small-hf  (fast, ~4GB VRAM)
      - depth-anything/Depth-Anything-V2-Base-hf   (balanced, ~6GB VRAM)
      - depth-anything/Depth-Anything-V2-Large-hf  (best quality, ~12GB VRAM)
    """

    MODEL_ID = "depth-anything/Depth-Anything-V2-Large-hf"

    def __init__(self):
        self._pipe = None
        self.device = settings.DEVICE

    async def load(self):
        """Load model weights into memory (runs in thread pool)."""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_sync)

    def _load_sync(self):
        logger.info(f"Loading depth model: {self.MODEL_ID}")
        self._pipe = hf_pipeline(
            task="depth-estimation",
            model=self.MODEL_ID,
            device=0 if self.device == "cuda" else -1,
            torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
            cache_dir=settings.MODEL_CACHE_DIR,
        )
        logger.info("✅ Depth Anything V2 loaded")

    async def estimate(self, image: Image.Image) -> np.ndarray:
        """
        Estimate depth from a PIL Image.

        Returns:
            np.ndarray: Float32 depth map, shape (H, W), normalized 0-1
        """
        if self._pipe is None:
            raise RuntimeError("Depth model not loaded. Call .load() first.")

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, self._infer_sync, image)
        return result

    def _infer_sync(self, image: Image.Image) -> np.ndarray:
        output = self._pipe(image)
        depth = output["predicted_depth"]

        if hasattr(depth, "numpy"):
            depth = depth.numpy()
        elif hasattr(depth, "cpu"):
            depth = depth.cpu().numpy()

        # Normalize to [0, 1]
        depth = (depth - depth.min()) / (depth.ptp() + 1e-8)

        # Resize to match input image
        from PIL import Image as PILImage
        depth_img = PILImage.fromarray((depth * 255).astype(np.uint8))
        depth_img = depth_img.resize(image.size, PILImage.BILINEAR)
        return np.array(depth_img).astype(np.float32) / 255.0

    def unload(self):
        """Free GPU memory."""
        del self._pipe
        self._pipe = None
        if self.device == "cuda":
            torch.cuda.empty_cache()
        logger.info("Depth model unloaded")
