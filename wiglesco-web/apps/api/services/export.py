"""
WiggleAI — Export Service
Supports: Animated GIF, Animated WebP, MP4 (via ffmpeg), Lenticular strip PNG
"""
import asyncio
import os
from typing import List

import imageio
import numpy as np
from PIL import Image
from loguru import logger


class ExportService:

    async def export(
        self,
        frames: List[Image.Image],
        output_path: str,
        format: str = "gif",
        fps: int = 12,
        loop: int = 0,  # 0 = infinite loop
    ) -> str:
        """Export frames to the specified format."""
        loop_obj = asyncio.get_event_loop()
        return await loop_obj.run_in_executor(
            None, self._export_sync, frames, output_path, format, fps, loop
        )

    def _export_sync(self, frames, output_path, format, fps, loop_count):
        if format == "gif":
            return self._export_gif(frames, output_path, fps, loop_count)
        elif format == "webp":
            return self._export_webp(frames, output_path, fps, loop_count)
        elif format == "mp4":
            return self._export_mp4(frames, output_path, fps)
        elif format == "lenticular":
            return self._export_lenticular(frames, output_path)
        else:
            raise ValueError(f"Unsupported export format: {format}")

    def _export_gif(self, frames: List[Image.Image], path: str, fps: int, loop: int) -> str:
        """Export as optimized animated GIF using imageio."""
        duration_ms = int(1000 / fps)
        arrays = [np.array(f.convert("RGB")) for f in frames]

        # Ping-pong loop for smoother wiggle
        arrays_loop = arrays + arrays[1:-1][::-1]

        imageio.mimsave(
            path,
            arrays_loop,
            format="GIF",
            duration=duration_ms,
            loop=loop,
        )
        logger.info(f"GIF exported: {path} ({len(arrays_loop)} frames @ {fps}fps)")
        return path

    def _export_webp(self, frames: List[Image.Image], path: str, fps: int, loop: int) -> str:
        """Export as animated WebP (smaller file than GIF, better quality)."""
        duration_ms = int(1000 / fps)
        frames_rgb = [f.convert("RGBA") for f in frames]

        # Ping-pong
        frames_loop = frames_rgb + frames_rgb[1:-1][::-1]

        frames_loop[0].save(
            path,
            format="WEBP",
            save_all=True,
            append_images=frames_loop[1:],
            duration=duration_ms,
            loop=loop,
            quality=85,
            method=6,
        )
        logger.info(f"WebP exported: {path}")
        return path

    def _export_mp4(self, frames: List[Image.Image], path: str, fps: int) -> str:
        """Export as MP4 video using imageio-ffmpeg."""
        # Ping-pong frames
        arrays = [np.array(f.convert("RGB")) for f in frames]
        arrays_loop = arrays + arrays[1:-1][::-1]

        writer = imageio.get_writer(
            path,
            fps=fps,
            codec="libx264",
            quality=8,
            ffmpeg_params=["-crf", "18", "-pix_fmt", "yuv420p"],
        )
        for frame in arrays_loop:
            writer.append_data(frame)
        writer.close()
        logger.info(f"MP4 exported: {path}")
        return path

    def _export_lenticular(self, frames: List[Image.Image], path: str) -> str:
        """
        Export as lenticular interlaced strip.
        Each column of pixels is taken from alternating frames,
        creating a physical lenticular print when viewed with a lens array.
        """
        if not frames:
            raise ValueError("No frames to export")

        n = len(frames)
        w, h = frames[0].size
        arrays = [np.array(f.convert("RGB")) for f in frames]

        lenticular = np.zeros((h, w, 3), dtype=np.uint8)

        for x in range(w):
            frame_idx = x % n
            lenticular[:, x] = arrays[frame_idx][:, x]

        Image.fromarray(lenticular).save(path, "PNG")
        logger.info(f"Lenticular strip exported: {path} ({n} lenses)")
        return path
