# WiggleAI

An AI-powered Wiggle 3D, Stereogram, and Lenticular photo effect application. This project transforms a single photo into an animated 3D perspective parallax video, simulating the iconic look of 4-lens film cameras like the Nishika N8000.

![Turborepo](https://img.shields.io/badge/Turborepo-EF4444?style=flat-square&logo=turborepo&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js_15-000000?style=flat-square&logo=nextdotjs&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=flat-square&logo=pytorch&logoColor=white)
![CUDA](https://img.shields.io/badge/CUDA-76B900?style=flat-square&logo=nvidia&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=flat-square&logo=tailwind-css&logoColor=white)

---

## Technical Overview

WiggleAI processes images through a custom multi-stage pipeline:
1. **Depth Estimation:** Extracts pixel-level distance mapping from a single source image.
2. **Novel View Synthesis:** Simulates multi-view perspective shift using horizontal depth warping.
3. **Inpainting / Border Extension:** Fills disocclusion gaps on the image boundaries.
4. **Post-Processing / Color Grading:** Simulates film properties (vignette, film grain, chromatic aberration, and retro-warm tinting).
5. **Frame Assembly:** Sequences individual frames into a looping MP4, WebP, or GIF.

---

## Project Structure

```text
wiggleai/
├── apps/
│   ├── web/        # Next.js 15 frontend application
│   └── api/        # FastAPI backend service
├── ml/
│   ├── scripts/    # Model downloads and CLI testing scripts
│   └── notebooks/  # Jupyter model experimentation
├── infra/
│   ├── docker/     # Container configurations
│   ├── k8s/        # Kubernetes manifests
│   └── terraform/  # Cloud infrastructure as code
└── docker-compose.yml
```

---

## Local Development Setup

For local GPU execution on consumer hardware (such as GTX 1650 4GB VRAM), the application runs in Direct Local Mode. This bypasses Celery, Redis, and Postgres, executing the pipeline synchronously within the FastAPI server.

### Prerequisites
* Node.js 20 or higher
* Python 3.11.x or 3.12.x
* NVIDIA GPU with CUDA Toolkit installed (for hardware-accelerated inference)

### 1. Backend Service Setup

Navigate to the API folder, set up the Python virtual environment, install dependencies, and run the FastAPI server:

```powershell
# Change directory
cd apps/api

# Create virtual environment
python -m venv venv

# Activate virtual environment (Windows)
.\venv\Scripts\activate

# Install required packages
pip install -r requirements.txt

# Start backend server
$env:PYTHONUTF8 = "1"
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

The API endpoints and interactive documentation will be available at: http://localhost:8000/docs

### 2. Frontend Application Setup

In a new terminal window, install npm packages and start the Next.js development server:

```bash
# From the project root
npm run dev
```

The web editor interface will be available at: http://localhost:3000

---

## Pipeline and Model Configurations

The backend utilizes Depth-Anything-V2 models. Depending on your system VRAM, configure the model sizes using environmental variables inside `apps/api/.env`:

| Model | Resource Size | Default Target | Purpose |
|---|---|---|---|
| Depth Anything V2 Small | 1.3 GB | Low-VRAM (GTX 1650) | Depth estimation |
| Depth Anything V2 Base | 2.5 GB | Mid-VRAM | Depth estimation |
| Real-ESRGAN x4plus | 67 MB | Optional | Resolution enhancement |

### Low-VRAM Optimization Profile
On systems with 4GB VRAM:
* SVD (Stable Video Diffusion) synthesis is disabled, falling back to Classical Depth Warping.
* SDXL Inpaint is bypassed, falling back to an Edge-Extend fill method.
* Upscaling via Real-ESRGAN is disabled by default to maintain healthy VRAM headroom.

---

## Project Roadmap

| Phase | Description | Status |
|---|---|---|
| Phase 0 | Setup and Foundation | Completed |
| Phase 1 | AI Pipeline Prototype | Completed |
| Phase 2 | Backend API Foundation | Completed |
| Phase 3 | Frontend Editor UI | In Progress |
| Phase 4 | Pipeline Integration | Pending |
| Phase 5 | Gallery and Social Sharing | Pending |
| Phase 6 | Monetization | Pending |
| Phase 7 | API Developer Platform | Pending |
| Phase 8 | Production Release | Pending |

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
