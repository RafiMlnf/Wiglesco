# Wiglesco Mobile — Project Progress Checklist (Flutter)

> **Created:** 2026-06-28
> **Active Phase:** Phase 1 (Backend Connection) → Phase 2 (Screens) — DONE
> **Tech Stack:** Flutter + Dart + FastAPI Backend (shared)
> **Target Platform:** Android APK (primary), iOS (secondary)
> **Arsitektur:** Standalone native app — bukan PWA, bukan WebView

---

## Ringkasan Arsitektur

```
┌─────────────────────────────────────────────────────────┐
│              WIGLESCO MOBILE (Flutter / Dart)           │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │    Home /   │  │   Editor    │  │   Result /      │ │
│  │   Gallery   │  │   Screen    │  │   Export Screen │ │
│  │   Screen    │  │             │  │                 │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
│                                                         │
│  Native: Camera, Gallery, FileSystem, Share, Video      │
│  State: Riverpod (Provider pattern)                     │
│  Routing: GoRouter (declarative)                        │
└─────────────┬───────────────────────────────────────────┘
              │ HTTP multipart/form-data  (dio)
              ▼
┌─────────────────────────────────────────────────────────┐
│              WIGLESCO BACKEND (FastAPI)                  │
│              apps/api — SHARED dengan web               │
│                                                         │
│  POST /api/v1/process/direct                            │
│  GET  /outputs/<filename>  (static files)               │
└─────────────────────────────────────────────────────────┘
```

**Catatan penting:**
- Backend **tidak diubah** — mobile pakai endpoint yang sama dengan web
- Logic identik: upload foto → depth estimation → parallax synthesis → return video URL
- Format output: MP4 / GIF / WebP (sama persis)
- Backend dijalankan dengan `--host 0.0.0.0` agar bisa diakses dari device fisik via LAN

---

## Tech Stack Decision

| Layer | Pilihan | Alasan |
|---|---|---|
| **Framework** | **Flutter 3.x (stable)** | Native performance, single codebase Android+iOS, APK kecil (~10MB) |
| **Bahasa** | **Dart 3.x** | Null-safe, strongly typed, async/await modern |
| **State Management** | **Riverpod 2.x** | Type-safe, compile-time checked, no BuildContext dependency |
| **Navigation** | **GoRouter** | Declarative routing, deep link support |
| **HTTP Client** | **Dio** | Multipart upload, interceptors, timeout config |
| **Camera/Gallery** | **image_picker** | Official Flutter plugin, Android + iOS |
| **Video Player** | **video_player** | Official Flutter plugin, hardware decode |
| **File System** | **path_provider** + **dart:io** | Akses storage lokal native |
| **Save ke Gallery** | **gal** | Save MP4/image ke camera roll (modern, aktif maintained) |
| **Share** | **share_plus** | Native share sheet (WhatsApp, Instagram, dll) |
| **Animasi** | **Flutter built-in** + **flutter_animate** | Smooth 60/120fps, tidak perlu library besar |
| **Icons** | **Material Icons** (built-in) + **Lucide** | Tidak perlu CDN |
| **Storage Lokal** | **shared_preferences** + **Hive** | Simpan history & settings |
| **Permissions** | **permission_handler** | Runtime permission Android/iOS |
| **UI Theme** | **Material 3 + Custom Dark Theme** | Premium dark look |

---

## Pemetaan Logic: Web → Flutter

| Feature Web | Implementasi Flutter | Status |
|---|---|---|
| Drag & Drop zone | `image_picker` → camera atau gallery | Planned |
| Parallax strength slider | `Slider` widget (native Material) | Planned |
| Frames selector (3/4/6/8) | `ChoiceChip` horizontal row | Planned |
| FPS slider | `Slider` widget | Planned |
| Style preset selector | Horizontal `ListView` dengan cards | Planned |
| Format selector (mp4/gif/webp) | `SegmentedButton` (Material 3) | Planned |
| Tab viewer (Original/Depth/Output) | `TabBar` + `TabBarView` | Planned |
| Loading overlay + shimmer | `Stack` + `AnimatedOpacity` + shimmer | Planned |
| Processing stats panel | `Card` di result screen | Planned |
| Session history (10 items) | `GridView` / `ListView` + Hive | Planned |
| Save Output | `gal` → Camera Roll | Planned |
| Share | `share_plus` native sheet | Planned |
| Backend health check | Dio ping + `SnackBar` status | Planned |
| HEIC support | `image_picker` handle native | Planned |
| Error handling | `AlertDialog` + retry | Planned |

---

## Phase 0: Setup & Foundation

- [ ] **Install Flutter SDK** (jika belum):
  ```powershell
  # Download Flutter SDK dari https://flutter.dev/docs/get-started/install/windows
  # Atau via winget:
  winget install Google.Flutter
  # Verifikasi:
  flutter doctor
  ```
- [ ] **Setup Android SDK** (Flutter doctor akan guide):
  - Install Android Studio (minimal untuk SDK + emulator)
  - Atau cukup: Android command-line tools + `sdkmanager`
  - Accept licenses: `flutter doctor --android-licenses`
- [ ] **Buat project Flutter** di folder `mobile/`:
  ```powershell
  cd d:\Coding\Stereogram\mobile
  flutter create . --org com.wiglesco --project-name wiglesco_mobile --platforms android,ios
  # atau pakai template kosong:
  flutter create . --org com.wiglesco --project-name wiglesco_mobile --empty
  ```
- [ ] **Tambah semua dependencies** ke `pubspec.yaml`:
  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    # State management
    flutter_riverpod: ^2.6.1
    riverpod_annotation: ^2.3.5
    # Navigation
    go_router: ^14.6.2
    # HTTP
    dio: ^5.7.0
    # Camera & media
    image_picker: ^1.1.2
    video_player: ^2.9.1
    # File system & storage
    path_provider: ^2.1.4
    # Save & share
    gal: ^2.3.0
    share_plus: ^10.0.3
    # Local storage
    shared_preferences: ^2.3.3
    hive_flutter: ^1.1.0
    # Permissions
    permission_handler: ^11.3.1
    # UI helpers
    flutter_animate: ^4.5.0
    shimmer: ^3.0.0
    cached_network_image: ^3.4.1
  
  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^5.0.0
    build_runner: ^2.4.13
    riverpod_generator: ^2.4.3
    hive_generator: ^2.0.1
  ```
- [ ] Jalankan `flutter pub get`
- [ ] Setup **Android permissions** di `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
  <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
      android:maxSdkVersion="29" />
  <uses-permission android:name="android.permission.CAMERA" />
  ```
- [ ] Setup **app icon** (ganti `assets/icon/icon.png` + jalankan `flutter pub run flutter_launcher_icons`)
- [ ] Setup **splash screen** (via `flutter_native_splash`)
- [ ] Buat **design system** `lib/core/theme.dart`:
  - Dark color scheme (mirip web: background `#0a0a0f`, accent gradient)
  - Typography (Google Fonts — `Inter`)
  - Custom colors, border radius, spacing

**Deliverable:** `flutter run` → blank screen dengan dark theme Wiglesco

---

## Phase 1: Backend Connection Layer

- [ ] Buat `lib/core/config.dart`:
  ```dart
  // Default: 10.0.2.2 untuk Android emulator → localhost host machine
  // Untuk device fisik: ganti ke IP LAN (misal 192.168.1.x)
  class AppConfig {
    static String backendBaseUrl = 'http://10.0.2.2:8000';
  }
  ```
- [ ] Buat `lib/services/api_client.dart` — Dio instance:
  ```dart
  // Base options: baseUrl, connectTimeout 10s, receiveTimeout 120s
  // Interceptor: log request/response, handle error globally
  ```
- [ ] Buat `lib/services/process_service.dart` — fungsi utama:
  ```dart
  Future<ProcessResult> processImage({
    required File imageFile,
    required int numFrames,
    required double parallaxStrength,
    required String effectStyle,
    required String exportFormat,
    required int fps,
  })
  // Build FormData, POST ke /api/v1/process/direct
  // Return ProcessResult model
  ```
- [ ] Buat `lib/models/process_result.dart` (data class / Dart record):
  ```dart
  class ProcessResult {
    final String outputUrl;
    final String depthMapUrl;
    final String thumbnailUrl;
    final double processingTime;
  }
  ```
- [ ] Buat `lib/models/history_item.dart`:
  ```dart
  @HiveType(typeId: 0)
  class HistoryItem extends HiveObject {
    String id, filename, outputUrl, depthMapUrl, thumbnailUrl, style;
    double processingTime;
    DateTime createdAt;
  }
  ```
- [ ] Health check endpoint: GET `/` → tampilkan status di `SnackBar`

**Deliverable:** Bisa kirim foto dari gallery ke backend dan terima `ProcessResult`

---

## Phase 2: Core Screens

### 2A: Home Screen (`lib/screens/home_screen.dart`)
- [ ] Branding header — "Wiglesco" dengan gradient text
- [ ] Hero area — animated illustration atau logo
- [ ] Tombol **"Pick from Gallery"** → `ImagePicker.pickImage(ImageSource.gallery)`
- [ ] Tombol **"Take Photo"** → `ImagePicker.pickImage(ImageSource.camera)`
- [ ] Backend status chip (🟢 Connected / 🔴 Offline)
- [ ] Recent history — horizontal `ListView` 5 item terakhir
- [ ] FAB atau bottom nav tab

### 2B: Editor Screen (`lib/screens/editor_screen.dart`)
- [ ] Preview foto — `Image.file()` full width dengan rounded corners
- [ ] **Control Panel** — scrollable `Column` di bawah preview:

  ```
  ┌─ Parallax Displacement ──────────────────────┐
  │  ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
  └──────────────────────────────────────────────┘
  
  ┌─ Frames ─────────────────────────────────────┐
  │  [ 3 ]  [ 4 ]  [ 6 ]  [ 8 ]                 │
  └──────────────────────────────────────────────┘
  
  ┌─ Frame Rate ─────────────────────────────────┐
  │  ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
  └──────────────────────────────────────────────┘
  
  ┌─ Style Preset ───────────────────────────────┐
  │  ← [ Normal ] [ Nishika ] [ Analog ] [ .. ] →│
  └──────────────────────────────────────────────┘
  
  ┌─ Format ─────────────────────────────────────┐
  │       [ MP4 ]   [ GIF ]   [ WebP ]           │
  └──────────────────────────────────────────────┘
  ```

- [ ] Tombol **"Render Parallax"** — full-width, gradient, bottom
- [ ] Loading overlay saat processing:
  - `AnimatedOpacity` dark overlay
  - Animated progress steps teks (Uploading... → Estimating depth... → dll)
  - `LinearProgressIndicator` shimmer
- [ ] Error snackbar + retry

### 2C: Result Screen (`lib/screens/result_screen.dart`)
- [ ] **Video player** — `VideoPlayer` widget, autoplay, loop
  - Controls: play/pause, mute toggle
- [ ] **Tab bar** — Original | Depth Map | 3D Parallax
  - Original: `Image.file()` dari file lokal
  - Depth Map: `CachedNetworkImage` dari `depth_map_url`
  - 3D Parallax: `VideoPlayer` dari `output_url`
- [ ] **Stats card**:
  - Processing time, format, frames, style preset
- [ ] **Action buttons**:
  - 💾 **Save to Gallery** → `gal.putVideo()` / `gal.putImage()`
  - 📤 **Share** → `Share.shareXFiles([XFile(path)])`
  - 🔄 **Edit Again** → pop ke editor
  - ➕ **New Photo** → pop ke home
- [ ] Auto-save ke history saat result screen dibuka

### 2D: History Screen (`lib/screens/history_screen.dart`)
- [ ] `GridView` 2 kolom — thumbnail tiap render
- [ ] `CachedNetworkImage` untuk thumbnail
- [ ] Tap item → buka Result screen dengan data tersimpan
- [ ] Long press → `showModalBottomSheet` opsi delete
- [ ] Empty state illustration

### 2E: Settings Screen (`lib/screens/settings_screen.dart`)
- [ ] `TextField` — Backend URL (default `http://10.0.2.2:8000`)
- [ ] Tombol **Test Connection** → ping backend
- [ ] Simpan ke `shared_preferences`
- [ ] Info: versi app, tentang Wiglesco
- [ ] Tombol **Clear History**

**Deliverable:** Full flow berjalan end-to-end

---

## Phase 3: State Management (Riverpod)

- [ ] `lib/providers/editor_provider.dart`:
  ```dart
  @riverpod
  class EditorState extends _$EditorState {
    // selectedImage, numFrames, strength, style, format, fps
    // isLoading, currentStep, error
    // Future<void> processImage()
  }
  ```
- [ ] `lib/providers/history_provider.dart`:
  ```dart
  @riverpod
  class HistoryState extends _$HistoryState {
    // List<HistoryItem> — max 20 item
    // void addItem(HistoryItem)
    // void deleteItem(String id)
    // void clearAll()
    // persist ke Hive
  }
  ```
- [ ] `lib/providers/settings_provider.dart`:
  ```dart
  @riverpod
  class SettingsState extends _$SettingsState {
    // backendUrl — SharedPreferences
    // isBackendConnected
    // Future<bool> checkConnection()
  }
  ```
- [ ] Jalankan code generation: `dart run build_runner build`

**Deliverable:** State terpisah bersih dari UI, reactive updates

---

## Phase 4: Navigation (GoRouter)

- [ ] Setup `lib/core/router.dart`:
  ```dart
  final router = GoRouter(routes: [
    GoRoute(path: '/',       builder: (_,__) => HomeScreen()),
    GoRoute(path: '/editor', builder: (_,__) => EditorScreen()),
    GoRoute(path: '/result', builder: (_,__) => ResultScreen()),
    GoRoute(path: '/history',builder: (_,__) => HistoryScreen()),
    GoRoute(path: '/settings',builder: (_,__) => SettingsScreen()),
  ]);
  ```
- [ ] **Bottom Navigation Bar**:
  - 🏠 Home
  - 🕐 History
  - ⚙️ Settings
- [ ] Transisi antar screen: custom `PageTransitionsTheme` (fade/slide)

---

## Phase 5: UI Polish & Animations

- [ ] **flutter_animate** — animasi entrance tiap screen:
  - Fade + slide up saat screen muncul
  - Scale bounce untuk tombol render
  - Staggered animation untuk cards
- [ ] **Shimmer** loading untuk thumbnail history
- [ ] **Hero animation** untuk preview foto (Home → Editor transition)
- [ ] Haptic feedback saat render selesai: `HapticFeedback.mediumImpact()`
- [ ] Custom `SnackBar` dengan icon
- [ ] Pull-to-refresh di history screen
- [ ] Empty state illustrations (SVG via `flutter_svg`)

---

## Phase 6: Build APK

### 6A: Debug APK (untuk testing)
```powershell
cd d:\Coding\Stereogram\mobile
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### 6B: Release APK
```powershell
# 1. Generate keystore (sekali saja):
keytool -genkey -v -keystore wiglesco-release.jks -keyAlias wiglesco -keyalg RSA -keysize 2048 -validity 10000

# 2. Setup android/key.properties (jangan di-commit ke git)

# 3. Update android/app/build.gradle untuk signing config

# 4. Build release APK:
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (~10-15MB)

# Atau build App Bundle (untuk Play Store):
flutter build appbundle --release
```

### 6C: Testing di Device / Emulator
```powershell
# List devices:
flutter devices

# Run di emulator:
flutter run

# Install APK langsung ke device via USB:
flutter install
```

**Deliverable:** APK siap di-install di Android device

---

## Struktur Folder Flutter

```
mobile/
├── lib/
│   ├── main.dart                    # Entry point, ProviderScope, MaterialApp
│   ├── core/
│   │   ├── theme.dart               # Dark theme, colors, typography
│   │   ├── router.dart              # GoRouter setup
│   │   └── config.dart              # AppConfig (backend URL default)
│   ├── models/
│   │   ├── process_result.dart      # API response model
│   │   └── history_item.dart        # Hive model (persistent)
│   ├── services/
│   │   ├── api_client.dart          # Dio instance
│   │   └── process_service.dart     # processImage() function
│   ├── providers/
│   │   ├── editor_provider.dart     # Editor state (Riverpod)
│   │   ├── history_provider.dart    # History state + Hive
│   │   └── settings_provider.dart   # Settings + SharedPrefs
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── editor_screen.dart
│   │   ├── result_screen.dart
│   │   ├── history_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/
│       ├── common/
│       │   ├── app_button.dart
│       │   ├── loading_overlay.dart
│       │   ├── status_badge.dart
│       │   └── section_header.dart
│       ├── editor/
│       │   ├── control_panel.dart
│       │   ├── style_selector.dart
│       │   ├── frame_selector.dart
│       │   └── format_selector.dart
│       └── result/
│           ├── video_view.dart
│           ├── tab_viewer.dart
│           ├── stats_card.dart
│           └── action_buttons.dart
├── assets/
│   ├── images/
│   │   ├── icon.png                 # 1024x1024 app icon
│   │   └── splash.png
│   └── fonts/                       # Inter font files (atau via google_fonts)
├── android/
│   └── app/
│       └── src/main/
│           └── AndroidManifest.xml  # Permissions
├── pubspec.yaml                     # Dependencies
└── README.md
```

---

## Cara Jalankan Development

```powershell
# 1. Start backend — PENTING: pakai --host 0.0.0.0
cd d:\Coding\Stereogram\apps\api
$env:PYTHONUTF8 = "1"
.\\venv\\Scripts\\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
# Catatan: 0.0.0.0 agar bisa diakses dari emulator/device, bukan hanya localhost

# 2. Start Flutter (di terminal lain)
cd d:\Coding\Stereogram\mobile
flutter run

# 3. Backend URL yang dipakai:
# - Android Emulator   → http://10.0.2.2:8000   (default di AppConfig)
# - Device fisik WiFi  → http://<IP-LAN-PC>:8000 (set di Settings screen)
#   Cari IP PC: ipconfig | findstr "IPv4"
```

---

## Perbedaan Web vs Flutter Mobile

| Aspek | Web (Next.js) | Flutter Mobile |
|---|---|---|
| Input foto | Drag & drop / `<input type=file>` | `ImagePicker` native sheet |
| Layout | 3-panel desktop | Single column + bottom nav |
| Video | HTML `<video>` autoplay | `VideoPlayer` + controller |
| Save output | Browser download | `gal.putVideo()` → Camera Roll |
| Share | `navigator.share()` | `share_plus` native sheet |
| History | Session-only (React state) | Persisten via Hive database |
| Backend URL | Hardcoded `localhost:8000` | Configurable di Settings screen |
| HTTP | `fetch()` browser API | `Dio` HTTP client |
| Styling | Tailwind CSS | Material 3 + custom `ThemeData` |
| APK size | N/A (web) | ~10–15MB release |
| Deploy | Vercel | APK install langsung |

---

## Bug Fixes & Catatan Teknis Flutter

| Item | Catatan |
|---|---|
| `10.0.2.2` vs `localhost` | Android emulator tidak bisa akses `localhost` — pakai `10.0.2.2` |
| Backend `--host 0.0.0.0` | Wajib agar emulator/device bisa akses, bukan `127.0.0.1` |
| `dio` timeout | Set `receiveTimeout` minimal 120 detik — pipeline ~25 detik + network |
| FormData file upload | Gunakan `MultipartFile.fromFile(file.path)` bukan bytes |
| Video cache | Download video dulu ke `path_provider` temp dir, baru play lokal |
| Android permissions | `READ_MEDIA_IMAGES` (Android 13+) vs `READ_EXTERNAL_STORAGE` (older) |
| Release signing | Jangan commit `key.properties` dan `.jks` ke git |
| `flutter doctor` | Pastikan semua ✅ sebelum mulai (terutama Android toolchain) |

---

## Progress Tracking

| Phase | Status | Target |
|---|---|---|
| Phase 0: Setup & Foundation | ✅ Done | 2026-06-28 |
| Phase 1: Backend Connection Layer | ✅ Done | 2026-06-28 |
| Phase 2A: Home Screen | ✅ Done | 2026-06-28 |
| Phase 2B: Editor Screen | ✅ Done | 2026-06-28 |
| Phase 2C: Result Screen | ✅ Done | 2026-06-28 |
| Phase 2D: History Screen | ✅ Done | 2026-06-28 |
| Phase 2E: Settings Screen | ✅ Done | 2026-06-28 |
| Phase 3: State Management (Riverpod) | ✅ Done | 2026-06-28 |
| Phase 4: Navigation (GoRouter) | ✅ Done | 2026-06-28 |
| Phase 5: UI Polish & Animations | 🔲 Planned | - |
| Phase 6A: Debug APK Build | ✅ Done — app-debug.apk | 2026-06-28 |
| Phase 6B: Release APK Build | 🔲 Planned | - |
