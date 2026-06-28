# Wiglesco Mobile

Wiglesco Mobile is a premium, Leica-style, AI-powered Wiggle 3D and Stereogram photo effect application built with Flutter. It transforms a single photo into an animated 3D perspective parallax video, simulating the iconic look of 4-lens film cameras like the Nishika N8000.

Wiglesco Mobile adalah aplikasi efek foto Wiggle 3D dan Stereogram berbasis AI dengan antarmuka premium bergaya Leica/Hasselblad. Proyek ini mengubah satu foto biasa menjadi video paralaks perspektif 3D bergerak, mereproduksi tampilan khas dari kamera analog 4 lensa legendaris seperti Nishika N8000.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-000000?style=flat-square&logo=riverpod&logoColor=white)
![ONNX Runtime](https://img.shields.io/badge/ONNX_Runtime-00599C?style=flat-square&logo=onnx&logoColor=white)
![FFmpeg](https://img.shields.io/badge/FFmpeg-007800?style=flat-square&logo=ffmpeg&logoColor=white)

---

## Key Features / Fitur Utama

### 1. Hybrid AI Processing Pipeline
*   **Serverless Mode (100% Offline):** Runs a local monocular depth estimation model (**Depth Anything V2**) using ONNX Runtime directly on the device, followed by coordinate-warping in Dart and compilation using FFmpeg.
*   **Server Mode:** Offloads the heavy lift to a local or remote FastAPI GPU backend via high-speed multipart uploads, downloading the visually lossless MP4 output and thumbnail automatically.
*   *Mode Serverless berjalan offline 100% di HP Anda. Mode Server mengirim pemrosesan ke server eksternal/PC dengan GPU melalui API FastAPI.*

### 2. Premium Minimalist UI
*   Zero emoji, neutral dark-charcoal palette, and clean typography.
*   Glassmorphic rendering buttons with shimmering outer glow strokes.
*   Interactive segmented pill switcher (`SERVERLESS` | `SERVER`) with live dynamic 2x2 details grid (Processor, AI Model, Internet requirements, Data Privacy info).

### 3. Ping-Pong Rendering Loop
*   Renders frames in a looping bounce path (`1-2-3-4-3-2-1`) for incredibly smooth wigglegram stereoscope effects.

---

## Technical Stack / Tumpukan Teknologi

*   **Framework:** Flutter (Dart)
*   **State Management:** Flutter Riverpod
*   **On-Device AI Inference:** ONNX Runtime (`onnxruntime: ^0.2.0`)
*   **Video Encoding:** FFmpeg Kit (`ffmpeg_kit_flutter_full_gpl: ^6.0.3`)
*   **Network Client:** Dio (`dio: ^5.7.0`)
*   **Local Cache & Storage:** Path Provider & SharedPreferences

---

## Local Development Setup / Panduan Setup Lokal

### Prerequisites
*   Flutter SDK (v3.22.x or higher)
*   Android Studio / Xcode
*   An Android or iOS device (or emulator)

### 1. Model Download (For Serverless / On-Device Mode)
To run on-device inference, you must download the quantized ONNX model and place it in the assets folder:
1.  Download **Depth Anything V2 Small Quantized** ONNX model.
2.  Create a folder `assets/models/` in the mobile root directory.
3.  Place the downloaded model and name it: `depth_anything_v2_vit_small.onnx`.

### 2. Installation & Running
Clone the repository and run the project in debug mode:

```bash
# Get dependencies
flutter pub get

# Run on your connected device
flutter run
```

### 3. Server Mode Connection
If you want to use **Server Mode** connected to your local FastAPI backend:
1.  Ensure your laptop/PC is running the FastAPI backend on port `8000` (e.g. using `run_local.bat`).
2.  Ensure your phone and laptop are on the same WiFi network.
3.  Go to the **Settings** screen in the mobile app, toggle mode to **SERVER**, and enter the URL:
    *   For Android Emulator: `http://10.0.2.2:8000`
    *   For Physical Devices: `http://<your-laptop-ip>:8000` (e.g., `http://192.168.1.8:8000`)
4.  Tap **TEST** to verify the handshake connection.

---

## License / Lisensi

This project is licensed under the MIT License.
*Proyek ini dilisensikan di bawah Lisensi MIT.*
