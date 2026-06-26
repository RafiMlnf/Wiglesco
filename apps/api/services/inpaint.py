"""WiggleAI — Inpainting Service stub"""
import asyncio
from typing import List
import numpy as np
from PIL import Image
from loguru import logger
from core.config import settings


class InpaintingService:
    """
    Fills disoccluded areas that appear when frames shift due to parallax.
    Uses SDXL Inpaint or a classical fill as fallback.
    """
    def __init__(self):
        self._pipe = None

    async def load(self):
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_sync)

    def _load_sync(self):
        # Skip SDXL load on low-VRAM GPUs (GTX 1650 etc.)
        if not settings.USE_SDXL_INPAINT:
            logger.info("Inpainting: edge-extend fill mode (SDXL Inpaint disabled — needs 8GB+ VRAM)")
            return
        try:
            from diffusers import AutoPipelineForInpainting
            import torch
            self._pipe = AutoPipelineForInpainting.from_pretrained(
                "diffusers/stable-diffusion-xl-1.0-inpainting-0.1",
                torch_dtype=torch.float16,
                variant="fp16",
                cache_dir=settings.MODEL_CACHE_DIR,
            ).to(settings.DEVICE)
            logger.info("✅ SDXL Inpaint loaded")
        except Exception as e:
            logger.warning(f"SDXL Inpaint load failed ({e}), using edge-extend fill")
            self._pipe = None

    async def fill_disocclusions(
        self,
        frames: List[Image.Image],
        depth_map: np.ndarray,
    ) -> List[Image.Image]:
        """Fill black/empty border regions created by parallax warping."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._fill_sync, frames, depth_map)

    def _fill_sync(self, frames, depth_map):
        filled = []
        for frame in frames:
            arr = np.array(frame)
            # Simple edge-extend fill: replace black border columns with nearest valid pixel
            filled_arr = self._edge_extend_fill(arr)
            filled.append(Image.fromarray(filled_arr))
        return filled

    def _edge_extend_fill(self, arr: np.ndarray) -> np.ndarray:
        """Replicate edge pixels into any all-black border columns/rows."""
        result = arr.copy()
        H, W = result.shape[:2]
        # Left edge
        for x in range(W):
            col = result[:, x]
            if col.sum() > 0:
                break
            if x + 1 < W:
                result[:, x] = result[:, x + 1]
        # Right edge
        for x in range(W - 1, -1, -1):
            col = result[:, x]
            if col.sum() > 0:
                break
            if x - 1 >= 0:
                result[:, x] = result[:, x - 1]
        return result
