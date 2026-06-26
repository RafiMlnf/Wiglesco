# WiggleAI — Project Progress Checklist

> **Last Updated:** 2026-06-26
> **Active Phase:** Phase 1 (Core AI Pipeline) + Phase 3A (Frontend Editor UI)
> **Hardware:** GTX 1650, 4GB VRAM — Localhost Testing Only

---

## Phase 0: Setup & Foundation

- [x] Setup monorepo dengan **Turborepo**
- [x] Init **Next.js 15** dengan TypeScript + Tailwind CSS
- [x] Init **FastAPI** backend dengan struktur folder modular (`routers/`, `services/`, `workers/`, `models/`)
- [ ] ~~Setup PostgreSQL + Redis via Docker Compose~~ — *ditunda, Phase 1 pakai direct local mode*
- [ ] ~~Setup Cloudflare R2 bucket~~ — *ditunda, Phase 1 pakai local storage*
- [ ] Setup GitHub repository + branch strategy
- [ ] Setup GitHub Actions CI
- [ ] Setup ESLint + Prettier + Husky
- [x] Buat `.env.example` / `core/config.py` dengan environment variables

**Deliverable status:** Partial — dev environment running locally tanpa Docker

---

## Phase 1: Core AI Pipeline — Research & Prototype

### Depth Estimation
- [x] Download & test **Depth Anything V2 Small** (dioptimasi untuk 4GB VRAM)
- [x] Validasi pada foto landscape & portrait (file `Gemini_Generated_Image_gq9igigq9igigq9i.png`)
- [ ] Buat visualizer depth map interaktif (sudah ada static PNG, belum point cloud)

### Novel View Synthesis
- [x] Model synthesis SVD/ZeroNVS diskip (butuh >6GB VRAM), pakai **classical depth warp** (INTER_CUBIC + Gaussian blur) untuk Phase 1
- [x] Generate 4–8 frame parallax dari 1 foto dengan offset ±5–70%
- [ ] ~~Bandingkan ZeroNVS vs SVD~~ — *tidak berlaku untuk GTX 1650*

### Inpainting
- [x] SD XL Inpaint diskip (butuh 8GB+ VRAM) → pakai **edge-extend fill**
- [x] Implementasi `InpaintingService` dengan bypass mode untuk low-VRAM

### Frame Assembly
- [x] Script Python: depth → parallax → N frames → **MP4** (bukan GIF)
- [x] Validasi output — efek mendekati Nishika N8000 dengan style preset
- [x] `ml/scripts/prototype_wiggle.py` — running end-to-end ✓

### Benchmark (partial)
- [x] Processing time: ~25 detik untuk 6 frame 1280x720 di GTX 1650
- [x] GPU VRAM: 4.2GB free saat depth model loaded (headroom aman)
- [ ] SSIM score antar frame — belum diukur formal

### Environment Setup
- [x] Python 3.11.9 virtual environment di `apps/api/venv/`
- [x] PyTorch 2.7.1 + CUDA 11.8
- [x] `check_env.py` — semua green ✓
- [x] `requirements_phase1.txt` — semua library terinstall
- [x] `services/storage.py` — local filesystem storage (ganti S3/R2)
- [x] `apps/api/main.py` — direct local API mode (tanpa Celery/Redis/DB)
- [x] Fix `numpy.ptp()` deprecated (numpy 2.x) di semua service
- [x] Fix `torch_dtype` → `dtype` di depth service

**Deliverable status:** DONE — pipeline bisa convert foto → MP4 wiggle 3D end-to-end

---

## Phase 2: Backend API Foundation

> Scope dikurangi untuk Phase 1 localhost testing

- [x] **FastAPI** setup dengan struktur modular
- [x] `/api/v1/process/direct` endpoint — upload + pipeline + return URLs
- [x] **StaticFiles** mount di `/outputs` untuk serve hasil lokal
- [x] `routers/processing.py` — job submit + status endpoints (full-stack ready)
- [x] `routers/health.py` — health check endpoint
- [ ] ~~JWT Auth endpoints~~ — ditunda
- [ ] ~~Clerk/Supabase Auth~~ — ditunda
- [ ] ~~Celery + Redis~~ — ditunda (pipeline jalan direct/synchronous)
- [ ] ~~WebSocket real-time progress~~ — ditunda (frontend pakai polling status text)
- [ ] ~~Alembic migrations~~ — ditunda
- [ ] ~~Unit tests (Pytest)~~ — ditunda

**Deliverable status:** Partial — local direct API berjalan di `http://localhost:8000`

---

## Phase 3: Frontend Editor UI

### 3A: Editor Core (IN PROGRESS)
- [x] **Upload Zone** — drag & drop, preview instant, validasi format (JPEG/PNG/WebP)
- [x] **Control Panel:**
  - [x] Parallax Displacement slider
  - [x] Number of Frames selector (3/4/6/8)
  - [x] Frame Rate slider (6–30 fps)
  - [x] Style Preset selector (Normal/Nishika/Vintage/Cinematic/Glitch/Cyberpunk)
  - [x] Format selector (MP4/GIF/WebP)
- [x] **3-panel layout** — Left controls, Center canvas, Right stats/history
- [x] **Tab viewer** — Original / Depth Map / 3D Parallax
- [x] **Loading overlay** — shimmer bar + step status text
- [x] **Processing Stats panel** — time, format, resolution, backend
- [x] **Session History** — menyimpan 10 render terakhir dengan thumbnail
- [x] **Save Output** button (download direct link)
- [ ] **Progress Panel:** Real-time WebSocket progress (ditunda, pakai step text)
- [ ] **Before/After slider preview** — belum dibuat

### 3B: Post-Processing Editor
- [ ] Film grain intensity control — belum (tapi sudah ada di backend style)
- [ ] Chromatic aberration slider — belum
- [ ] Vignette control — belum
- [ ] Color grading (LUT) — belum

### 3C: Landing & Auth
- [ ] Landing page — belum
- [ ] Login/Register — ditunda

**Deliverable status:** Core editor UI functional, compact single-viewport layout

---

## Phase 4–8: Pipeline Integration, Gallery, Monetization, API, Launch

- [ ] Semua — belum dimulai (roadmap jangka panjang)

---

## Bug Fixes & Technical Debt Resolved

| Issue | Status |
|---|---|
| `numpy.ptp()` deprecated (numpy 2.x) di `depth.py`, `ai_pipeline.py`, `prototype_wiggle.py` | Fixed |
| `torch_dtype` deprecated → `dtype` di depth pipeline | Fixed |
| Depth tensor tidak di-squeeze (shape mismatch) | Fixed |
| MP4 macro_block_size warning (height not divisible by 16) | Known — tidak kritis |
| Real-ESRGAN `basicsr` module missing | Known — upscaling disabled, tidak kritis untuk Phase 1 |
| Unicode encode error di Windows terminal (emoji di print) | Fixed via `PYTHONUTF8=1` |
| Next.js Turbopack parse error (CSS `{}` dalam JSX template literal) | Fixed — CSS dipindah ke `globals.css` |

---

## Tools & Scripts Tersedia

| File | Fungsi |
|---|---|
| `ml/scripts/check_env.py` | Validasi GPU, VRAM, PyTorch, semua library |
| `ml/scripts/prototype_wiggle.py` | CLI tool: foto → wiggle MP4 |
| `wiggle.bat` | Launcher drag-and-drop untuk Windows |
| `run_local.bat` | Start backend + frontend sekaligus |

---

## Cara Jalankan Saat Ini

```powershell
# Terminal 1 — Backend (port 8000)
cd d:\Coding\Stereogram\apps\api
$env:PYTHONUTF8 = "1"
.\venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000

# Terminal 2 — Frontend (port 3000)
cd d:\Coding\Stereogram
npm run dev
```

Buka: **http://localhost:3000**
