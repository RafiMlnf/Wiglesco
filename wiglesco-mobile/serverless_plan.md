# Wiglesco Mobile — Serverless (On-Device) Architecture Plan

> **Created:** 2026-06-28
> **Goal:** Hilangkan ketergantungan pada server FastAPI. Semua proses berjalan 100% di Android — tidak butuh WiFi, tidak butuh PC.
> **Status:** 🏆 Completed (All Phases Implemented)

---

## Ringkasan Masalah

Sebelumnya app Flutter memanggil server backend FastAPI:
```
POST http://10.0.2.2:8000/api/v1/process/direct
```

**Sekarang (Serverless):**
- Berjalan 100% offline secara lokal di perangkat Android.
- Menggunakan ONNX Runtime Mobile untuk estimasi depth map.
- Parallax warping dan style rendering ditulis dalam pure Dart.
- Video encoding (MP4/GIF/WebP) diproses langsung via native FFmpeg Kit.

---

## Pipeline On-Device (Serverless)

```
Input Photo
    │
    ▼
[1] Preprocess      → Resize ke max 512px (Dart `image` package)
    │
    ▼
[2] Depth Estimation → Depth Anything V2 Small (.onnx) via `flutter_onnxruntime`
    │                  Output: grayscale depth map [0,1]
    ▼
[3] Parallax Synthesis → Pure Dart (3D Y-axis warp + Painter's Algorithm + hole fill)
    │                    Berjalan di background `Isolate`
    ▼
[4] Style/Enhancement → Pure Dart pixel ops (Nishika, Analog, Retro, Cinematic, Cyberpunk)
    │
    ▼
[5] Export Video → `ffmpeg_kit_flutter_full_gpl` (MP4/GIF/WebP)
    │
    ▼
Output: Saved to Local Storage & Gallery
```

---

## Analisa Feasibility Per Tahap

### [1] Preprocess — ✅ Selesai
- Resize gambar ke max 512px agar inference dan synthesis berjalan cepat.
- Library: `image` package (pure Dart).

### [2] Depth Estimation — ✅ Selesai
- Menggunakan **ONNX Runtime (`flutter_onnxruntime`)** dengan model `depth_anything_v2_small.onnx` (99MB).
- Jauh lebih stabil dan akurat dibandingkan konversi TFLite yang sering mengalami `operator not supported` / `PyFunc` error.
- Inference input: `[1, 3, 518, 518]`, normalized (ImageNet mean & std).

### [3] Parallax Synthesis — ✅ Selesai
- Berhasil memporting novel view synthesis dari Python (NumPy/OpenCV) ke Dart.
- Menggunakan Painter's Algorithm (closer pixels render last) dan nearest-neighbor hole filling untuk area disocclusion.
- Berjalan dalam background `Isolate.run()` agar UI tidak lag.

### [4] Style/Enhancement — ✅ Selesai
- Memporting seluruh preset filter (Nishika, Analog, Retro Warm, Cinematic, Glitch, Cyberpunk) ke Dart.
- Mendukung grain, vignette, dan chromatic aberration secara lokal.

### [5] Export Video — ✅ Selesai
- Menggunakan `ffmpeg_kit_flutter_full_gpl` untuk melisensikan encoder `libx264` (MP4) serta format GIF berkualitas tinggi via `lanczos` palettegen.

---

## Perubahan Arsitektur

### Sebelum (Server-Dependent)
```
Flutter App  ──[Upload Photo]──>  FastAPI Backend (PC)
                                         │
                                   [PyTorch CUDA]
                                         │
Flutter App  <──[Download Video]───  Output URL
```

### Sesudah (Serverless On-Device)
```
Flutter App (100% Offline)
    ├── depth_service.dart     (ONNX Runtime Mobile)
    ├── synthesis_service.dart (Dart Isolate Warp)
    ├── style_service.dart     (Dart Pixel Filters)
    └── export_service.dart    (FFmpeg Kit GPL)
```

---

## Progress Tracking

| Phase | Status | Deskripsi |
|---|---|---|
| **Phase A: Setup ONNX Depth** | ✅ Completed | Model `.onnx` berhasil di-load via `flutter_onnxruntime` |
| **Phase B: Parallax Synthesis Port** | ✅ Completed | Algoritma warp & hole fill berjalan di background Isolate |
| **Phase C: Style Effects Port** | ✅ Completed | Porting filter analog film, grain, vignette, chromatic aberration |
| **Phase D: FFmpeg Video Export** | ✅ Completed | MP4, GIF, dan WebP di-encode secara lokal |
| **Phase E: UI Integration** | ✅ Completed | EditorScreen & ResultScreen terhubung dengan local pipeline |

---

## Catatan Teknis
- **Proguard Rules:** Wajib menambahkan `-keep class ai.onnxruntime.** { *; }` di `android/app/proguard-rules.pro` untuk mencegah error saat release build.
- **Isolate:** Seluruh pemrosesan intensif (warp synthesis) didelegasikan ke `Isolate.run` untuk menjaga 60 FPS pada UI thread.
