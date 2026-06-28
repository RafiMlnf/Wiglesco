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
        img_array = np.array(image).astype(np.uint8)
        H, W = img_array.shape[:2]

        import cv2 as _cv2

        # Bilateral filter to smooth flat areas while preserving sharp edges
        try:
            depth_smooth = _cv2.bilateralFilter(depth_map.astype(np.float32), 5, 0.1, 5)
        except Exception:
            depth_smooth = _cv2.GaussianBlur(depth_map.astype(np.float32), (5, 5), 0)

        # Map normalized depth [0, 1] to virtual Z values (Near = 1.0, Far = 2.5)
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
        depth_mean = float(np.mean(depth_smooth))
        Z_focus = 1.0 + (1.0 - depth_mean) * 1.5

        # Max horizontal camera rotation angle (in radians)
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
            Z_rot = X * sin_t + Z_rel * cos_t + Z_focus

            # Prevent division by zero or negative depth
            Z_rot = np.maximum(Z_rot, 0.1)

            # Project back to 2D target coordinates
            x_t = (X_rot / Z_rot) * f + cx
            y_t = (map_norm_y * Z / Z_rot) * f + cy

            # Round to nearest pixel grid index
            ix = np.round(x_t).astype(np.int32)
            iy = np.round(y_t).astype(np.int32)

            # Flatten arrays for vectorized Painter's Algorithm
            ix_flat = ix.ravel()
            iy_flat = iy.ravel()
            z_flat = Z_rot.ravel()
            colors_flat = img_array.reshape(-1, 3)

            # Filter valid pixels within bounds
            valid = (ix_flat >= 0) & (ix_flat < W) & (iy_flat >= 0) & (iy_flat < H)
            ix_valid = ix_flat[valid]
            iy_valid = iy_flat[valid]
            z_valid = z_flat[valid]
            colors_valid = colors_flat[valid]

            # Sort by depth descending (farther pixels first, closer foreground pixels overwrite them)
            sort_idx = np.argsort(z_valid)[::-1]
            ix_sorted = ix_valid[sort_idx]
            iy_sorted = iy_valid[sort_idx]
            colors_sorted = colors_valid[sort_idx]

            # Draw to canvas and keep track of drawn pixels
            warped = np.zeros((H, W, 3), dtype=np.uint8)
            occupied = np.zeros((H, W), dtype=np.uint8)
            
            warped[iy_sorted, ix_sorted] = colors_sorted
            occupied[iy_sorted, ix_sorted] = 1

            # Disocclusion mask (empty areas where occupied == 0)
            mask = (occupied == 0).astype(np.uint8) * 255

            # Inpaint the disocclusions (Photoshop-style Clone Stamp / Telea method)
            inpainted = _cv2.inpaint(warped, mask, inpaintRadius=5, flags=_cv2.INPAINT_TELEA)

            # Crop the inpainted frame to remove outer border holes
            crop_w = int(W * 0.05 * parallax_strength)
            crop_w = np.clip(crop_w, 4, int(W * 0.12))
            crop_h = int(H * (crop_w / W))

            # Crop using numpy slicing
            cropped = inpainted[crop_h:H-crop_h, crop_w:W-crop_w]

            # Resize back to original dimensions for a seamless fit
            warped_resized = _cv2.resize(cropped, (W, H), interpolation=_cv2.INTER_CUBIC)

            frames.append(Image.fromarray(warped_resized))

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
