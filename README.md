# WiggleAI 🎬

> **AI-powered Wiggle 3D / Stereogram / Lenticular photo effect app**  
> Transform any single photo into a stunning animated 3D GIF — inspired by the iconic Nishika N8000 4-lens camera.

---

## ✨ How it Works

```
Photo (1 image) → Depth AI → Novel View Synthesis → Inpaint → Enhance → Wiggle 3D GIF
```

Unlike simple image blending, WiggleAI uses a chain of AI models to generate photorealistic parallax frames from a single photo.

---

## 🗂 Project Structure

```
wiggleai/
├── apps/
│   ├── web/        # Next.js 15 frontend (TypeScript + Tailwind)
│   └── api/        # FastAPI backend (Python 3.12)
├── ml/
│   ├── scripts/    # Download models, prototype scripts
│   └── notebooks/  # Jupyter experiments
├── infra/
│   ├── docker/     # Dockerfiles
│   ├── k8s/        # Kubernetes manifests
│   └── terraform/  # Infrastructure as Code
└── docker-compose.yml
```

---

## 🚀 Quick Start (Development)

### Prerequisites
- Node.js 20+
- Python 3.12+
- Docker + Docker Compose
- NVIDIA GPU (optional, for AI processing)

### 1. Clone & Setup

```bash
git clone https://github.com/yourname/wiggleai.git
cd wiggleai

# Copy env template
cp .env.example .env
# Edit .env with your values
```

### 2. Start Infrastructure

```bash
# Start Postgres + Redis
docker compose up postgres redis -d
```

### 3. Start Backend

```bash
cd apps/api
python -m venv venv
venv\Scripts\activate   # Windows
# source venv/bin/activate  # Linux/Mac

pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

API docs: http://localhost:8000/docs

### 4. Start Frontend

```bash
cd apps/web
npm install
npm run dev
```

Web app: http://localhost:3000

### 5. Start Celery Worker (AI Processing)

```bash
cd apps/api
celery -A workers.tasks:celery_app worker --loglevel=info --concurrency=1
```

### 6. Monitor Jobs (Optional)

```bash
cd apps/api
celery -A workers.tasks:celery_app flower --port=5555
```

Flower dashboard: http://localhost:5555

---

## 🤖 AI Pipeline Prototype (Phase 1 Test)

Test the pipeline from command line without running the full stack:

```bash
cd apps/api
pip install -r requirements.txt

python ../../ml/scripts/prototype_wiggle.py \
  --input your_photo.jpg \
  --output output.gif \
  --frames 4 \
  --strength 0.6 \
  --style nishika
```

---

## 🤖 Download AI Models

```bash
python ml/scripts/download_models.py
```

Required models (total ~40GB with all models):
| Model | Size | Purpose |
|---|---|---|
| Depth Anything V2 Large | 1.3 GB | Depth estimation |
| Real-ESRGAN x4plus | 67 MB | Upscaling |
| Stable Video Diffusion | 25 GB | Novel view synthesis |
| SDXL Inpaint | 12 GB | Disocclusion fill |

> 💡 For development/testing, only Depth Anything V2 is required — the pipeline falls back to classical depth warp without SVD.

---

## 🛣 Roadmap

| Phase | Description | Status |
|---|---|---|
| 0 | Setup & Foundation | ✅ Done |
| 1 | AI Pipeline Prototype | 🔄 In Progress |
| 2 | Backend API | ⏳ Pending |
| 3 | Frontend Editor UI | ⏳ Pending |
| 4 | Full Integration | ⏳ Pending |
| 5 | Gallery & Social | ⏳ Pending |
| 6 | Monetization | ⏳ Pending |
| 7 | API Platform | ⏳ Pending |
| 8 | Production Launch | ⏳ Pending |

---

## 📄 License

MIT License — see [LICENSE](LICENSE)
