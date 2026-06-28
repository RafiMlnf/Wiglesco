#!/usr/bin/env python3
"""
WiggleAI — GPU & Environment Check
Run this first to verify everything is working before the full prototype.

Usage:
    python ml/scripts/check_env.py
"""
import sys
print("=" * 55)
print("  WiggleAI — Environment Check")
print("=" * 55)

# Python version
print(f"\n✅ Python: {sys.version.split()[0]}")
if sys.version_info < (3, 11):
    print("  ⚠️  Warning: Python 3.11+ recommended")

# NumPy
try:
    import numpy as np
    print(f"✅ NumPy: {np.__version__}")
except ImportError:
    print("❌ NumPy not installed")

# Pillow
try:
    from PIL import Image
    import PIL
    print(f"✅ Pillow: {PIL.__version__}")
except ImportError:
    print("❌ Pillow not installed")

# OpenCV
try:
    import cv2
    print(f"✅ OpenCV: {cv2.__version__}")
except ImportError:
    print("❌ OpenCV not installed")

# imageio + ffmpeg
try:
    import imageio
    print(f"✅ imageio: {imageio.__version__}")
    try:
        import imageio_ffmpeg
        ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
        print(f"✅ ffmpeg: {ffmpeg_exe}")
    except Exception as e:
        print(f"⚠️  ffmpeg: {e}")
except ImportError:
    print("❌ imageio not installed")

# PyTorch
print()
try:
    import torch
    print(f"✅ PyTorch: {torch.__version__}")
    if torch.cuda.is_available():
        gpu = torch.cuda.get_device_properties(0)
        total_gb = gpu.total_memory / 1e9
        free_gb = (gpu.total_memory - torch.cuda.memory_allocated(0)) / 1e9
        print(f"✅ CUDA: {torch.version.cuda}")
        print(f"✅ GPU:  {gpu.name}")
        print(f"✅ VRAM: {total_gb:.1f}GB total / {free_gb:.1f}GB free")
        if total_gb < 4:
            print("   ⚠️  Less than 4GB VRAM — some models may OOM")
        elif total_gb < 6:
            print("   ℹ️  4-6GB VRAM — GTX 1650 mode (Small depth model, classical warp)")
        else:
            print("   ℹ️  6GB+ VRAM — consider upgrading to Base/Large depth model")
    else:
        print("⚠️  CUDA not available — running CPU only (slower)")
except ImportError:
    print("❌ PyTorch not installed — run:")
    print("   pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118")

# Transformers
try:
    import transformers
    print(f"✅ Transformers: {transformers.__version__}")
except ImportError:
    print("❌ Transformers not installed")

# Diffusers
try:
    import diffusers
    print(f"✅ Diffusers: {diffusers.__version__}")
except ImportError:
    print("⚠️  Diffusers not installed (needed for SVD/SDXL, optional for Phase 1)")

# Config
print()
try:
    sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent.parent.parent / "apps" / "api"))
    from core.config import settings
    print(f"✅ Config loaded:")
    print(f"   DEVICE:              {settings.DEVICE}")
    print(f"   DEPTH_MODEL_SIZE:    {settings.DEPTH_MODEL_SIZE}")
    print(f"   USE_DIFFUSION:       {settings.USE_DIFFUSION_SYNTHESIS}")
    print(f"   USE_SDXL_INPAINT:    {settings.USE_SDXL_INPAINT}")
    print(f"   INPUT_MAX_LONG_SIDE: {settings.INPUT_MAX_LONG_SIDE}px")
    print(f"   MODEL_CACHE_DIR:     {settings.MODEL_CACHE_DIR}")
    print(f"   OUTPUT_DIR:          {settings.OUTPUT_DIR}")
except Exception as e:
    print(f"⚠️  Config error: {e}")

print()
print("=" * 55)
print("  All checks done. If all ✅, run the prototype:")
print()
print("  python ml/scripts/prototype_wiggle.py \\")
print("    --input your_photo.jpg \\")
print("    --output wiggle.mp4 \\")
print("    --style nishika --strength 0.7")
print("=" * 55)
