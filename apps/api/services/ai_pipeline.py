"""
WiggleAI — AI Pipeline Orchestrator
Chains: Depth Estimation → Novel View Synthesis → Inpainting → Enhancement → Export
"""
import asyncio
import time
import uuid
from pathlib import Path
from typing import Callable, Optional

import numpy as np
from PIL import Image
from loguru import logger

from core.config import settings
from services.depth import DepthEstimationService
from services.synthesis import NovelViewSynthesisService
from services.inpaint import InpaintingService
from services.enhance import EnhancementService
from services.export import ExportService
from services.storage import StorageService


class PipelineStep:
    """Represents a single pipeline step with name and weight for progress tracking."""
    def __init__(self, name: str, display: str, weight: float):
        self.name = name
        self.display = display
        self.weight = weight  # Relative weight for progress calculation


PIPELINE_STEPS = [
    PipelineStep("preprocess",  "📐 Preprocessing image",          0.05),
    PipelineStep("segment",     "🎭 Segmenting scene layers",       0.10),
    PipelineStep("depth",       "🌊 Estimating depth map",          0.20),
    PipelineStep("synthesis",   "🎨 Synthesizing parallax frames",  0.35),
    PipelineStep("inpaint",     "🖌️ Filling disoccluded areas",    0.15),
    PipelineStep("enhance",     "✨ Enhancing & upscaling frames",  0.10),
    PipelineStep("export",      "📦 Exporting final output",        0.05),
]


class AIPipeline:
    """
    Main AI pipeline orchestrator for WiggleAI.

    Usage:
        pipeline = AIPipeline()
        result = await pipeline.run(
            image_path="input.jpg",
            job_id="uuid",
            num_frames=4,
            parallax_strength=0.5,
            effect_style="nishika",
            export_format="gif",
            progress_callback=my_callback,
        )
    """

    def __init__(self):
        self.depth_service = DepthEstimationService()
        self.synthesis_service = NovelViewSynthesisService()
        self.inpaint_service = InpaintingService()
        self.enhance_service = EnhancementService()
        self.export_service = ExportService()
        self.storage_service = StorageService()
        self._initialized = False

    async def initialize(self):
        """Load all AI models into memory. Call once at worker startup."""
        if self._initialized:
            return
        logger.info("Loading AI models...")
        await asyncio.gather(
            self.depth_service.load(),
            self.synthesis_service.load(),
            self.inpaint_service.load(),
            self.enhance_service.load(),
        )
        self._initialized = True
        logger.info("✅ All models loaded")

    async def run(
        self,
        image_path: str,
        job_id: str,
        num_frames: int = 4,
        parallax_strength: float = 0.5,
        effect_style: str = "normal",
        export_format: str = "gif",
        fps: int = 12,
        progress_callback: Optional[Callable] = None,
    ) -> dict:
        """
        Execute full AI pipeline and return output URLs.

        Returns:
            {
                "output_url": str,
                "depth_map_url": str,
                "thumbnail_url": str,
                "processing_time": float,
            }
        """
        start_time = time.time()
        accumulated_progress = 0.0
        work_dir = Path(f"/tmp/wiggleai/{job_id}")
        work_dir.mkdir(parents=True, exist_ok=True)

        async def report(step: PipelineStep, done: bool = False):
            nonlocal accumulated_progress
            if done:
                accumulated_progress += step.weight
            pct = min(accumulated_progress * 100, 99.0)
            if progress_callback:
                await progress_callback(
                    step=step.name,
                    display=step.display,
                    progress=pct,
                )

        try:
            # ── Step 1: Preprocess ────────────────────────────────────────
            step = PIPELINE_STEPS[0]
            await report(step)
            image = Image.open(image_path).convert("RGB")
            image = self._preprocess_image(image)
            image.save(work_dir / "input_clean.png")
            await report(step, done=True)

            # ── Step 2: Depth Estimation ──────────────────────────────────
            step = PIPELINE_STEPS[2]
            await report(step)
            depth_map = await self.depth_service.estimate(image)
            depth_path = work_dir / "depth_map.png"
            self._save_depth_visualization(depth_map, depth_path)
            await report(step, done=True)

            # ── Step 3: Novel View Synthesis ──────────────────────────────
            step = PIPELINE_STEPS[3]
            await report(step)
            frames = await self.synthesis_service.generate_frames(
                image=image,
                depth_map=depth_map,
                num_frames=num_frames,
                parallax_strength=parallax_strength,
            )
            await report(step, done=True)

            # ── Step 4: Inpainting Disoccluded Areas ─────────────────────
            step = PIPELINE_STEPS[4]
            await report(step)
            frames = await self.inpaint_service.fill_disocclusions(
                frames=frames,
                depth_map=depth_map,
            )
            await report(step, done=True)

            # ── Step 5: Enhancement ────────────────────────────────────────
            step = PIPELINE_STEPS[5]
            await report(step)
            frames = await self.enhance_service.process(
                frames=frames,
                style=effect_style,
                upscale=(export_format in ["mp4", "webp"]),
            )
            await report(step, done=True)

            # ── Step 6: Export ─────────────────────────────────────────────
            step = PIPELINE_STEPS[6]
            await report(step)
            output_path = work_dir / f"output.{export_format}"
            thumbnail_path = work_dir / "thumbnail.webp"

            await self.export_service.export(
                frames=frames,
                output_path=str(output_path),
                format=export_format,
                fps=fps,
            )
            # Generate thumbnail from middle frame
            mid = frames[len(frames) // 2]
            mid.save(str(thumbnail_path), "WEBP", quality=85)

            # ── Upload to Storage ─────────────────────────────────────────
            base = f"jobs/{job_id}"
            output_url = await self.storage_service.upload(str(output_path), f"{base}/output.{export_format}")
            depth_url = await self.storage_service.upload(str(depth_path), f"{base}/depth_map.png")
            thumb_url = await self.storage_service.upload(str(thumbnail_path), f"{base}/thumbnail.webp")
            await report(step, done=True)

            processing_time = time.time() - start_time
            logger.info(f"✅ Job {job_id} completed in {processing_time:.1f}s")

            return {
                "output_url": output_url,
                "depth_map_url": depth_url,
                "thumbnail_url": thumb_url,
                "processing_time": processing_time,
            }

        except Exception as e:
            logger.error(f"❌ Pipeline failed for job {job_id}: {e}")
            raise
        finally:
            # Cleanup temp files
            import shutil
            shutil.rmtree(work_dir, ignore_errors=True)

    def _preprocess_image(self, image: Image.Image) -> Image.Image:
        """Resize and normalize image for pipeline."""
        max_dim = settings.MAX_IMAGE_DIMENSION
        w, h = image.size
        if max(w, h) > max_dim:
            scale = max_dim / max(w, h)
            image = image.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        return image

    def _save_depth_visualization(self, depth_map: np.ndarray, path: Path):
        """Save depth map as colorized PNG for visualization."""
        import cv2
        depth_norm = ((depth_map - depth_map.min()) / (depth_map.ptp() + 1e-8) * 255).astype(np.uint8)
        depth_colored = cv2.applyColorMap(depth_norm, cv2.COLORMAP_MAGMA)
        cv2.imwrite(str(path), depth_colored)
