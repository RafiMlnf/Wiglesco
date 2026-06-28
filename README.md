# Wiglesco — Monorepo

Wiglesco is an AI-powered Wiggle 3D, Stereogram, and Lenticular photo effect application. This repository contains both the web portal & API backend and the premium cross-platform Flutter mobile client. It transforms a single photo into an animated 3D perspective parallax video, simulating the iconic look of 4-lens film cameras like the Nishika N8000.

Wiglesco adalah aplikasi efek foto Wiggle 3D, Stereogram, dan Lenticular berbasis AI. Repositori ini berisi portal web & API backend serta aplikasi mobile Flutter premium. Proyek ini mengubah satu foto biasa menjadi video paralaks perspektif 3D bergerak, mereproduksi tampilan khas dari kamera analog 4 lensa legendaris seperti Nishika N8000.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js_15-000000?style=flat-square&logo=nextdotjs&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)
![ONNX Runtime](https://img.shields.io/badge/ONNX_Runtime-00599C?style=flat-square&logo=onnx&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=flat-square&logo=pytorch&logoColor=white)
![CUDA](https://img.shields.io/badge/CUDA-76B900?style=flat-square&logo=nvidia&logoColor=white)

---

## Repository Structure / Struktur Repositori

The codebase is split into two cleanly decoupled components:
*   **[wiglesco-mobile/](./wiglesco-mobile)**: The premium cross-platform Flutter application supporting local offline (serverless) ONNX inference and server API processing.
*   **[wiglesco-web/](./wiglesco-web)**: The Turborepo-managed workspace hosting the Next.js 15 web client, python FastAPI backend API, ML prototyping scripts, and deployment infrastructure.

*Repositori ini dibagi menjadi dua bagian terpisah:*
*   *`wiglesco-mobile/`: Aplikasi mobile berbasis Flutter dengan UI Leica-style premium.*
*   *`wiglesco-web/`: Workspace Turborepo berisi aplikasi web Next.js dan backend FastAPI Python.*

---

## Technology Stack / Tumpukan Teknologi

### Mobile Application
*   **Flutter & Dart**: Cross-platform application framework and programming language.
    *   *Framework aplikasi multiplatform dan bahasa pemrograman.*
*   **Riverpod**: State management and dependency injection.
    *   *Manajemen state aplikasi dan dependency injection.*
*   **ONNX Runtime**: Client-side execution engine for the on-device Depth Anything V2 model.
    *   *Engine eksekusi client-side untuk menjalankan model AI Depth Anything V2 secara offline.*
*   **FFmpeg Kit**: On-device video encoding and frame compilation.
    *   *Encoding video dan kompilasi frame langsung di dalam perangkat mobile.*
*   **Dio**: High-performance HTTP client for multipart uploads to the backend.
    *   *Client HTTP untuk mengunggah file gambar ke server backend.*

### Web & Backend API
*   **Next.js 15**: React framework for the web editor interface.
    *   *Framework React untuk membangun antarmuka editor berbasis web.*
*   **FastAPI**: Modern, high-performance Python web framework for the AI pipeline API.
    *   *Framework web Python berkinerja tinggi untuk melayani API pipeline AI.*
*   **PyTorch**: Deep learning framework powering depth estimation and synthesis models on the server.
    *   *Framework deep learning untuk menjalankan estimasi kedalaman dan model sintesis pada server.*
*   **Turborepo**: Monorepo orchestration tool for JS/TS applications and shared configurations.
    *   *Alat orkestrasi monorepo untuk manajemen aplikasi JS/TS dan konfigurasi bersama.*

---

## Technical Pipeline / Alur Teknis AI

Both platforms process input photos through the following pipeline:
1.  **Depth Estimation:** Monocular depth extraction from a single image using **Depth Anything V2**.
2.  **Novel View Synthesis:** Creates multi-view perspective frames using 3D coordinate depth warping.
3.  **Inpainting:** Extends image boundaries to fill disocclusion gaps (using edge-extension locally, or SDXL on server).
4.  **Styling / Analog Filter:** Simulates analog film properties (grain, warm tones, vignette, chromatic aberration).
5.  **Frame Assembly:** Encodes frames into a looping MP4 video or GIF using a ping-pong bounce loop (`1-2-3-4-3-2-1`) for smooth wigglegram simulation.

---

## Local Development Quick Start / Memulai Pengembangan Lokal

### 1. Web & Backend API Setup (`wiglesco-web`)

For local execution (e.g., GTX 1650 4GB VRAM), the FastAPI server runs in Direct Local Mode:

```bash
# Navigate to web & backend directory
cd wiglesco-web

# A. Set up and run Python FastAPI Backend
cd apps/api
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
# Start uvicorn server (bound to 0.0.0.0 for network access)
$env:PYTHONUTF8 = "1"
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# B. Set up and run Next.js Web Frontend (in a new terminal under wiglesco-web)
npm install
npm run dev
```

*   **API Interactive Documentation:** http://localhost:8000/docs
*   **Web Editor Interface:** http://localhost:3000

---

### 2. Mobile App Setup (`wiglesco-mobile`)

Built with Flutter & Riverpod. Supports fully offline local generation or FastAPI remote connection:

```bash
# Navigate to mobile directory
cd wiglesco-mobile

# Install packages
flutter pub get
```

#### On-Device ONNX Setup (For Offline Serverless Mode):
1.  Download the **Depth Anything V2 Small Quantized** ONNX model.
2.  Create directory `wiglesco-mobile/assets/models/`.
3.  Save the model inside it as `depth_anything_v2_vit_small.onnx`.
4.  Run on your physical device or emulator: `flutter run`

#### Connecting to your Local FastAPI Backend:
1.  Go to the **Settings** screen in the mobile app.
2.  Choose the **SERVER** mode pill.
3.  Enter the URL:
    *   *Android Emulator:* `http://10.0.2.2:8000`
    *   *Physical Phone:* `http://<your-computer-ip>:8000` (e.g., `http://192.168.1.8:8000`)
4.  Tap **TEST** to verify the connection.

---

## License / Lisensi

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
*Proyek ini dilisensikan di bawah Lisensi MIT.*
