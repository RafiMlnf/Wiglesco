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
        # Read from config — False for GTX 1650 (4GB VRAM), SVD needs 10GB+
        self.use_diffusion = settings.USE_DIFFUSION_SYNTHESIS

    async def load(self):
        """Load diffusion model if enabled (requires 10GB+ VRAM)."""
        if not self.use_diffusion:
            logger.info("Novel view synthesis: classical warp mode (GTX 1650 / low-VRAM mode, no diffusion model needed)")
            return
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_svd)

    def _load_svd(self):
        """Load Stable Video Diffusion img2vid. Requires ~10GB VRAM — NOT for GTX 1650."""
        try:
            from diffusers import StableVideoDiffusionPipeline
            if self.device == "cuda" and torch.cuda.is_available():
                total_gb = torch.cuda.get_device_properties(0).total_memory / 1e9
                if total_gb < 8:
                    logger.warning(f"⚠️ SVD requires 10GB+ VRAM, detected {total_gb:.1f}GB. Falling back to classical warp.")
                    self.use_diffusion = False
                    return
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

        # Smooth depth map slightly to reduce warping artifacts
        import cv2 as _cv2
        depth_smooth = _cv2.GaussianBlur(depth_map, (5, 5), 0)

        # Map normalized depth [0, 1] to virtual Z values (Near = 1.0, Far = 2.5)
        # Depth Anything V2: 1.0 is near, 0.0 is far
        Z = 1.0 + (1.0 - depth_smooth) * 1.5

        # Focal length (virtual camera) and center point
        f = max(H, W) * 1.2
        cx = W / 2.0
        cy = H / 2.0

        # Normalized coordinates relative to image center
        norm_x = (np.arange(W, dtype=np.float32) - cx) / f
        norm_y = (np.arange(H, dtype=np.float32) - cy) / f
        map_norm_x, map_norm_y = np.meshgrid(norm_x, norm_y)

        # Focus depth: dynamically set to mean depth of the image
        # Objects at this depth will remain stationary, acting as the pivot/focal point
        depth_mean = float(np.mean(depth_smooth))
        Z_focus = 1.0 + (1.0 - depth_mean) * 1.5

        # Max horizontal camera rotation angle (in radians): ~3.5 degrees at strength=1.0
        max_theta = 0.06 * parallax_strength
        thetas = np.linspace(-max_theta, max_theta, num_frames)

        frames = []
        for theta in thetas:
            cos_t = np.cos(theta)
            sin_t = np.sin(theta)

            # 3D coordinates relative to focus point
            X = map_norm_x * Z
            Z_rel = Z - Z_focus

            # 3D Camera Rotation around Y-axis (horizontal orbit/POV rotation)
            X_rot = X * cos_t - Z_rel * sin_t
            Y_rot = map_norm_y * Z  # Y coordinate stays constant for horizontal rotation
            Z_rot = X * sin_t + Z_rel * cos_t + Z_focus

            # Prevent division by zero or negative depth
            Z_rot = np.maximum(Z_rot, 0.1)

            # Project back to 2D image coordinates
            map_x_shifted = (X_rot / Z_rot) * f + cx
            map_y_shifted = (Y_rot / Z_rot) * f + cy

            # Warp the image using INTER_CUBIC for clean, sharp edges
            warped = _cv2.remap(
                img_array,
                map_x_shifted.astype(np.float32),
                map_y_shifted.astype(np.float32),
                interpolation=_cv2.INTER_CUBIC,
                borderMode=_cv2.BORDER_REPLICATE,
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
