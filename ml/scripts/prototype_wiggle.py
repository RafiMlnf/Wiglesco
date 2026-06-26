#!/usr/bin/env python3
"""
WiggleAI — Phase 1 Prototype Script
Test: Single image → Wiggle 3D GIF using classical depth warp
No GPU required for this classical mode.

Usage:
    python ml/scripts/prototype_wiggle.py --input photo.jpg --output out.gif --frames 4 --strength 0.6
"""
import argparse
import sys
from pathlib import Path

# Add project to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "apps" / "api"))


def run_prototype(input_path: str, output_path: str, num_frames: int, strength: float, style: str, fps: int):
    import asyncio
    import numpy as np
    from PIL import Image

    print(f"📷 Input:  {input_path}")
    print(f"🎥 Output: {output_path}")
    print(f"🔢 Frames: {num_frames}, Strength: {strength}, Style: {style}, FPS: {fps}")

    # GPU info
    try:
        import torch
        if torch.cuda.is_available():
            gpu = torch.cuda.get_device_properties(0)
            total_gb = gpu.total_memory / 1e9
            print(f"💻 GPU: {gpu.name} | VRAM: {total_gb:.1f}GB")
            if total_gb < 5:
                print("🔧 Low-VRAM mode: using Depth-Anything-V2-Small + classical warp (no diffusion)")
        else:
            print("⚠️  No CUDA GPU detected, running on CPU (slower depth estimation)")
    except ImportError:
        print("⚠️  PyTorch not installed")
    print()

    image = Image.open(input_path).convert("RGB")
    W, H = image.size
    print(f"📐 Image size: {W}x{H}")

    # Step 1: Depth estimation
    print("🌊 [1/4] Estimating depth...")
    try:
        from services.depth import DepthEstimationService
        depth_svc = DepthEstimationService()
        depth_map = asyncio.run(depth_svc.estimate(image))
        print(f"   ✅ Depth map shape: {depth_map.shape}, range: [{depth_map.min():.2f}, {depth_map.max():.2f}]")
    except Exception as e:
        print(f"   ⚠️ Depth model unavailable ({e}), using synthetic gradient depth")
        x = np.linspace(0, 1, W)
        y = np.linspace(0, 1, H)
        xx, yy = np.meshgrid(x, y)
        depth_map = (1 - yy).astype(np.float32)  # Simple top=far, bottom=near

    # Save depth visualization
    depth_vis_path = output_path.replace(".gif", "_depth.png")
    import cv2
    depth_norm = ((depth_map - depth_map.min()) / (depth_map.ptp() + 1e-8) * 255).astype(np.uint8)
    depth_colored = cv2.applyColorMap(depth_norm, cv2.COLORMAP_MAGMA)
    cv2.imwrite(depth_vis_path, depth_colored)
    print(f"   💾 Depth map saved: {depth_vis_path}")

    # Step 2: Generate frames
    print(f"🎨 [2/4] Generating {num_frames} parallax frames...")
    from services.synthesis import NovelViewSynthesisService
    synth = NovelViewSynthesisService()
    synth.use_diffusion = False  # Use classical warp for prototype
    frames = asyncio.run(synth.generate_frames(image, depth_map, num_frames, strength))
    print(f"   ✅ Generated {len(frames)} frames")

    # Step 3: Apply style
    print(f"✨ [3/4] Applying style: {style}...")
    from services.enhance import EnhancementService
    enhance = EnhancementService()
    frames = asyncio.run(enhance.process(frames, style=style, upscale=False))
    print(f"   ✅ Style applied")

    # Step 4: Export MP4
    print(f"📦 [4/4] Exporting {output_path.split('.')[-1].upper()}...")
    from services.export import ExportService
    export_svc = ExportService()
    fmt = output_path.split('.')[-1].lower()
    asyncio.run(export_svc.export(frames, output_path, format=fmt, fps=fps))
    
    import os
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"   ✅ Exported: {output_path} ({size_mb:.2f} MB)")
    print()
    print("🎉 Done! Play the MP4 to preview your Wiggle 3D effect.")
    print(f"   📁 Output: {output_path}")
    print(f"   🗺️  Depth:  {output_path.replace(output_path.split('.')[-1], 'depth.png')}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="WiggleAI Prototype — Single Image to Wiggle 3D")
    parser.add_argument("--input", "-i", required=True, help="Input image path (JPG/PNG)")
    parser.add_argument("--output", "-o", default="output_wiggle.mp4", help="Output path (.mp4/.gif/.webp)")
    parser.add_argument("--frames", "-f", type=int, default=4, choices=[3,4,6,8], help="Number of frames")
    parser.add_argument("--strength", "-s", type=float, default=0.5, help="Parallax strength (0.1-1.0)")
    parser.add_argument("--fps", type=int, default=15, help="Frames per second for MP4/GIF output")
    parser.add_argument("--style", default="normal", choices=["normal","nishika","vintage","cinematic","glitch","cyberpunk"])
    args = parser.parse_args()

    run_prototype(args.input, args.output, args.frames, args.strength, args.style, args.fps)
