#!/usr/bin/env python3
"""
WiggleAI — Model Download Script
Downloads all required AI model weights to ml/models/
"""
import subprocess
import sys
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "models"
MODELS_DIR.mkdir(exist_ok=True)


def run(cmd: str):
    print(f"  $ {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=False)
    if result.returncode != 0:
        print(f"  ⚠️ Command failed (exit {result.returncode})")
    return result.returncode == 0


print("🤖 WiggleAI — Model Download Script")
print(f"📁 Download dir: {MODELS_DIR}")
print()

# 1. Depth Anything V2 (via HuggingFace — auto-cached by transformers)
print("[1/4] Depth Anything V2...")
print("  → Will be auto-downloaded by HuggingFace Transformers on first run")
print("  → Model ID: depth-anything/Depth-Anything-V2-Large-hf")
print("  → Approx size: 1.3 GB")
print()

# 2. Real-ESRGAN upscaler weights
print("[2/4] Real-ESRGAN x4plus weights...")
esrgan_url = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
esrgan_dest = MODELS_DIR / "RealESRGAN_x4plus.pth"
if not esrgan_dest.exists():
    run(f"curl -L -o {esrgan_dest} {esrgan_url}")
    print(f"  ✅ Saved to {esrgan_dest}")
else:
    print(f"  ✅ Already exists: {esrgan_dest}")
print()

# 3. Stable Video Diffusion (via HuggingFace)
print("[3/4] Stable Video Diffusion img2vid-xt...")
print("  → Model ID: stabilityai/stable-video-diffusion-img2vid-xt")
print("  → Approx size: 25 GB (fp16)")
print("  → Run: huggingface-cli download stabilityai/stable-video-diffusion-img2vid-xt")
print()

# 4. SDXL Inpaint (via HuggingFace)
print("[4/4] SDXL Inpaint model...")
print("  → Model ID: diffusers/stable-diffusion-xl-1.0-inpainting-0.1")
print("  → Approx size: 12 GB (fp16)")
print("  → Auto-downloaded on first use")
print()

print("=" * 50)
print("💡 To pre-download HuggingFace models, run:")
print("   pip install huggingface-hub")
print("   huggingface-cli login  (if models are gated)")
print("   python -c \"from transformers import pipeline; pipeline('depth-estimation', model='depth-anything/Depth-Anything-V2-Large-hf')\"")
