"""
WiggleAI — Enhancement & Style Service
Applies: Nishika film effect, chromatic aberration, grain, vignette, upscale
"""
import asyncio
import random
from typing import List

import cv2
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
from loguru import logger

from core.config import settings


class EnhancementService:
    """
    Post-processing pipeline for frame enhancement and style application.
    
    Styles:
    - normal: Clean output, no stylization
    - nishika: Chromatic aberration, film grain, slight vignette (Nishika N8000 look)
    - vintage: Strong grain, desaturated warm tones, heavy vignette
    - cinematic: Teal & orange color grade, anamorphic lens flare
    - glitch: RGB split, scan lines, digital artifacts
    - cyberpunk: Neon boost, high contrast, purple/cyan shift
    """

    def __init__(self):
        self._esrgan = None

    async def load(self):
        """Load Real-ESRGAN upscaling model."""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_esrgan)

    def _load_esrgan(self):
        try:
            from basicsr.archs.rrdbnet_arch import RRDBNet
            from realesrgan import RealESRGANer
            model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
            self._esrgan = RealESRGANer(
                scale=4,
                model_path=f"{settings.MODEL_CACHE_DIR}/RealESRGAN_x4plus.pth",
                model=model,
                tile=settings.ESRGAN_TILE_SIZE,   # 256 for GTX 1650, 512 for 8GB+
                tile_pad=10,
                pre_pad=0,
                half=True,
            )
            logger.info(f"✅ Real-ESRGAN loaded (tile={settings.ESRGAN_TILE_SIZE}px for VRAM safety)")
        except Exception as e:
            logger.warning(f"Real-ESRGAN load failed: {e}. Upscaling disabled.")
            self._esrgan = None

    async def process(
        self,
        frames: List[Image.Image],
        style: str = "normal",
        upscale: bool = False,
    ) -> List[Image.Image]:
        """Apply style + optional upscale to all frames."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self._process_sync, frames, style, upscale
        )

    def _process_sync(self, frames, style, upscale):
        processed = []
        logger.info(f"✨ EnhancementService: applying style '{style}' to {len(frames)} frames (upscale={upscale})")
        for frame in frames:
            frame = self._apply_style(frame, style)
            if upscale and self._esrgan:
                frame = self._upscale_frame(frame)
            processed.append(frame)
        return processed

    def _apply_style(self, image: Image.Image, style: str) -> Image.Image:
        handlers = {
            "normal":    self._style_normal,
            "nishika":   self._style_nishika,
            "analog":    self._style_analog,
            "cinematic": self._style_cinematic,
            "glitch":    self._style_glitch,
            "cyberpunk": self._style_cyberpunk,
        }
        fn = handlers.get(style, self._style_normal)
        return fn(image)

    # ── Style: Normal ────────────────────────────────────────────
    def _style_normal(self, img: Image.Image) -> Image.Image:
        return img

    # ── Style: Nishika N8000 ─────────────────────────────────────
    def _style_nishika(self, img: Image.Image) -> Image.Image:
        arr = np.array(img).astype(np.float32)
        arr = self._add_chromatic_aberration(arr, strength=3)
        arr = self._add_film_grain(arr, intensity=18)
        arr = self._add_vignette(arr, strength=0.4)
        # Slight warm color shift (film emulsion character)
        arr[:, :, 0] = np.clip(arr[:, :, 0] * 1.04, 0, 255)  # R+
        arr[:, :, 2] = np.clip(arr[:, :, 2] * 0.96, 0, 255)  # B-
        return Image.fromarray(arr.astype(np.uint8))

    # ── Style: Analog Film (pure color grade) ────────────────────
    def _style_analog(self, img: Image.Image) -> Image.Image:
        """
        Analog/lomography color grading — no grain, no vignette, no overlays.
        1. Lift blacks: shadow floor raised to ~18, giving faded film character.
        2. Shadow teal-green push: R- G+ B+ in dark zones only.
        3. Midtone warmth: R+ B- in mid tones only.
        4. Highlight compression: subtle, keeps airy feel.
        """
        arr = np.array(img).astype(np.float32)

        # 1. Lift blacks — shadow floor 0 → ~18
        shadow_lift = 18.0
        arr = arr / 255.0
        arr = shadow_lift / 255.0 + arr * (1.0 - shadow_lift / 255.0)

        # Luminance per pixel [0,1]
        luma = 0.2126 * arr[:, :, 0] + 0.7152 * arr[:, :, 1] + 0.0722 * arr[:, :, 2]

        # Shadow zone weight (strongest below luma 0.35)
        shadow_w = np.clip(1.0 - luma / 0.35, 0.0, 1.0) ** 1.5
        shadow_w = shadow_w[:, :, np.newaxis]

        # Midtone zone weight (peaks at luma 0.5)
        mid_w = np.clip(1.0 - np.abs(luma - 0.5) / 0.35, 0.0, 1.0) ** 1.5
        mid_w = mid_w[:, :, np.newaxis]

        # 2. Shadow green push (R-, G+, B- to push shadows to deep olive/forest green)
        teal_shift = np.zeros_like(arr)
        teal_shift[:, :, 0] -= 0.080   # R- (stronger cut)
        teal_shift[:, :, 1] += 0.095   # G+ (strong green push)
        teal_shift[:, :, 2] -= 0.040   # B- (cuts blue to prevent purple shadows, shifts to green)
        arr = arr + teal_shift * shadow_w

        # 3. Midtone green-warmth (R+ subtle, G+ green cast, B- warm yellow)
        warm_shift = np.zeros_like(arr)
        warm_shift[:, :, 0] += 0.015   # R+
        warm_shift[:, :, 1] += 0.035   # G+ (pushed green into midtones)
        warm_shift[:, :, 2] -= 0.050   # B-
        arr = arr + warm_shift * mid_w

        # 4. Highlight compression (airy, not blown)
        hi_w = np.clip((luma - 0.85) / 0.15, 0.0, 1.0)[:, :, np.newaxis]
        arr = arr - arr * hi_w * 0.05

        arr = np.clip(arr * 255.0, 0, 255)
        return Image.fromarray(arr.astype(np.uint8))

    # ── Style: Cinematic ─────────────────────────────────────────
    def _style_cinematic(self, img: Image.Image) -> Image.Image:
        arr = np.array(img).astype(np.float32)
        # Teal shadows, orange highlights (Hollywood grade)
        shadows_mask = arr < 80
        highlights_mask = arr > 180
        arr[:, :, 2][shadows_mask[:, :, 2]] = np.clip(arr[:, :, 2][shadows_mask[:, :, 2]] * 1.2, 0, 255)
        arr[:, :, 0][highlights_mask[:, :, 0]] = np.clip(arr[:, :, 0][highlights_mask[:, :, 0]] * 1.15, 0, 255)
        arr = self._add_vignette(arr, strength=0.25)
        return Image.fromarray(arr.astype(np.uint8))

    # ── Style: Glitch ────────────────────────────────────────────
    def _style_glitch(self, img: Image.Image) -> Image.Image:
        arr = np.array(img).astype(np.float32)
        arr = self._add_chromatic_aberration(arr, strength=8)
        # Random horizontal scan-line glitches
        h = arr.shape[0]
        for _ in range(random.randint(3, 8)):
            y = random.randint(0, h - 5)
            offset = random.randint(-20, 20)
            arr[y:y+3] = np.roll(arr[y:y+3], offset, axis=1)
        return Image.fromarray(arr.astype(np.uint8))

    # ── Style: Cyberpunk ─────────────────────────────────────────
    def _style_cyberpunk(self, img: Image.Image) -> Image.Image:
        arr = np.array(img).astype(np.float32)
        # Boost neon: purple (R+B) and cyan (G+B)
        arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.3, 0, 255)  # B++
        arr[:, :, 0] = np.clip(arr[:, :, 0] * 1.1, 0, 255)  # R+
        # High contrast
        arr = np.clip((arr - 128) * 1.2 + 128, 0, 255)
        arr = self._add_vignette(arr, strength=0.5)
        arr = self._add_chromatic_aberration(arr, strength=2)
        return Image.fromarray(arr.astype(np.uint8))

    # ── Common Effects ───────────────────────────────────────────
    def _add_chromatic_aberration(self, arr: np.ndarray, strength: int = 3) -> np.ndarray:
        """Shift RGB channels by different offsets to simulate lens aberration."""
        result = arr.copy()
        result[:, :, 0] = np.roll(arr[:, :, 0], strength, axis=1)   # R shift right
        result[:, :, 2] = np.roll(arr[:, :, 2], -strength, axis=1)  # B shift left
        return result

    def _add_film_grain(self, arr: np.ndarray, intensity: float = 20.0) -> np.ndarray:
        """Add Gaussian noise simulating film grain."""
        grain = np.random.normal(0, intensity, arr.shape).astype(np.float32)
        return np.clip(arr + grain, 0, 255)

    def _add_vignette(self, arr: np.ndarray, strength: float = 0.4) -> np.ndarray:
        """Darken corners to simulate lens vignette."""
        H, W = arr.shape[:2]
        Y, X = np.ogrid[:H, :W]
        cx, cy = W / 2, H / 2
        # Normalized distance from center
        dist = np.sqrt(((X - cx) / cx) ** 2 + ((Y - cy) / cy) ** 2)
        dist = np.clip(dist, 0, 1)
        mask = 1 - dist * strength
        mask = mask[:, :, np.newaxis]
        return np.clip(arr * mask, 0, 255)

    def _upscale_frame(self, img: Image.Image) -> Image.Image:
        """Upscale 2x using Real-ESRGAN."""
        try:
            import cv2 as cv
            arr = cv.cvtColor(np.array(img), cv.COLOR_RGB2BGR)
            output, _ = self._esrgan.enhance(arr, outscale=2)
            return Image.fromarray(cv.cvtColor(output, cv.COLOR_BGR2RGB))
        except Exception as e:
            logger.warning(f"Upscale failed: {e}")
            return img
