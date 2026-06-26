"""
WiggleAI — Novel View Synthesis Service
Strategy: Depth-warping (fast classical) + optional diffusion refinement
"""
import asyncio
from typing import List

import cv2
import numpy as np
import torch
from PIL import Image
from loguru import logger

from core.config import settings


class NovelViewSynthesisService:
    """
    Generates N parallax frames from a single image + depth map.

    Two modes:
    1. CLASSICAL (fast, ~0.5s): Depth-based image warping using remap
       - Good for subtle parallax, stable, no GPU required
    2. DIFFUSION (high quality, ~30-60s): Stable Video Diffusion / ZeroNVS
       - Generates photorealistic novel views, requires GPU
    """

    def __init__(self):
        self._svd_pipe = None
        self.device = settings.DEVICE
        self.use_diffusion = True  # Set False for classical only mode

    async def load(self):
        """Load diffusion model if enabled."""
        if not self.use_diffusion:
            logger.info("Novel view synthesis: classical warp mode (no model needed)")
            return
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_svd)

    def _load_svd(self):
        """Load Stable Video Diffusion img2vid."""
        try:
            from diffusers import StableVideoDiffusionPipeline
            logger.info("Loading Stable Video Diffusion...")
            self._svd_pipe = StableVideoDiffusionPipeline.from_pretrained(
                "stabilityai/stable-video-diffusion-img2vid-xt",
                torch_dtype=torch.float16,
                variant="fp16",
                cache_dir=settings.MODEL_CACHE_DIR,
            )
            self._svd_pipe.to(self.device)
            self._svd_pipe.enable_model_cpu_offload()
            logger.info("✅ Stable Video Diffusion loaded")
        except Exception as e:
            logger.warning(f"SVD load failed ({e}), falling back to classical warp")
            self.use_diffusion = False

    async def generate_frames(
        self,
        image: Image.Image,
        depth_map: np.ndarray,
        num_frames: int = 4,
        parallax_strength: float = 0.5,
    ) -> List[Image.Image]:
        """
        Generate N frames with increasing parallax offset.

        Args:
            image: Original input PIL image
            depth_map: Float32 depth map [0,1], shape (H,W)
            num_frames: Number of output frames (3-8)
            parallax_strength: How strong the 3D effect is (0.1 - 1.0)

        Returns:
            List of PIL Images representing each frame
        """
        if self.use_diffusion and self._svd_pipe is not None:
            return await self._diffusion_frames(image, num_frames, parallax_strength)
        else:
            return await self._classical_warp_frames(image, depth_map, num_frames, parallax_strength)

    async def _classical_warp_frames(
        self,
        image: Image.Image,
        depth_map: np.ndarray,
        num_frames: int,
        parallax_strength: float,
    ) -> List[Image.Image]:
        """Fast depth-based image warping — used as fallback or standalone."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None,
            self._warp_sync,
            image, depth_map, num_frames, parallax_strength
        )

    def _warp_sync(self, image, depth_map, num_frames, parallax_strength):
        img_array = np.array(image).astype(np.float32)
        H, W = img_array.shape[:2]

        # Max pixel displacement based on strength (e.g. up to 5% of width)
        max_disp = int(W * 0.05 * parallax_strength)

        # Offsets: symmetric around 0
        offsets = np.linspace(-max_disp, max_disp, num_frames)

        frames = []
        for offset in offsets:
            # Create displacement map based on depth
            # Near objects (high depth value) shift more
            disp_map = depth_map * offset  # Shape: (H, W)

            # Build remap coordinates
            x_coords = np.arange(W, dtype=np.float32)
            y_coords = np.arange(H, dtype=np.float32)
            map_x, map_y = np.meshgrid(x_coords, y_coords)

            # Apply horizontal parallax shift
            map_x_shifted = (map_x + disp_map).astype(np.float32)
            map_y_shifted = map_y.astype(np.float32)

            # Remap image
            warped = cv2.remap(
                img_array,
                map_x_shifted,
                map_y_shifted,
                interpolation=cv2.INTER_LINEAR,
                borderMode=cv2.BORDER_REPLICATE,
            )
            frames.append(Image.fromarray(warped.astype(np.uint8)))

        return frames

    async def _diffusion_frames(self, image, num_frames, parallax_strength):
        """Use SVD to generate fluid motion frames."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None,
            self._svd_infer_sync,
            image, num_frames, parallax_strength
        )

    def _svd_infer_sync(self, image, num_frames, parallax_strength):
        if self._svd_pipe is None:
            raise RuntimeError("SVD not loaded")

        # SVD generates up to 25 frames — we'll select num_frames evenly
        with torch.no_grad():
            frames_tensor = self._svd_pipe(
                image,
                num_frames=25,
                motion_bucket_id=int(127 * parallax_strength),
                noise_aug_strength=0.02,
                decode_chunk_size=8,
            ).frames[0]

        # Select evenly spaced frames
        step = max(1, len(frames_tensor) // num_frames)
        selected = [frames_tensor[i * step] for i in range(num_frames)]
        return selected
