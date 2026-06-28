import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Port of Python EnhancementService — all color grading effects in pure Dart.
/// All operations work on pixel level using the `image` package.
class OnDeviceStyleService {
  /// Apply style preset to all frames.
  List<img.Image> applyStyle(List<img.Image> frames, String style) {
    return frames.map((f) => _applyStyle(f, style)).toList();
  }

  /// Apply style to a single frame.
  img.Image applyStyle1(img.Image frame, String style) =>
      _applyStyle(frame, style);

  img.Image _applyStyle(img.Image image, String style) {
    switch (style) {
      case 'nishika':
        return _styleNishika(image);
      case 'analog':
        return _styleAnalog(image);
      case 'retro_warm':
        return _styleRetroWarm(image);
      case 'cinematic':
        return _styleCinematic(image);
      case 'glitch':
        return _styleGlitch(image);
      case 'cyberpunk':
        return _styleCyberpunk(image);
      default:
        return image; // 'normal'
    }
  }

  // ── Style: Nishika N8000 ──────────────────────────────────

  img.Image _styleNishika(img.Image src) {
    var arr = _toFloat(src);
    arr = _addChromaticAberration(arr, src.width, src.height, 3);
    arr = _addFilmGrain(arr, 18.0);
    arr = _addVignette(arr, src.width, src.height, 0.4);
    // Warm shift: R*1.04, B*0.96
    for (int i = 0; i < arr.length; i += 3) {
      arr[i]     = (arr[i]     * 1.04).clamp(0, 255);   // R+
      arr[i + 2] = (arr[i + 2] * 0.96).clamp(0, 255);   // B-
    }
    return _fromFloat(arr, src.width, src.height);
  }

  // ── Style: Analog Film ────────────────────────────────────

  img.Image _styleAnalog(img.Image src) {
    final W = src.width;
    final H = src.height;
    var arr = _toFloat(src);
    final norm = Float64List(arr.length);

    // 1. Lift blacks → [0.0706, 1.0]
    const shadowLift = 18.0 / 255.0;
    for (int i = 0; i < arr.length; i++) {
      norm[i] = arr[i] / 255.0 * (1.0 - shadowLift) + shadowLift;
    }

    // Per-pixel luma + shadow/mid weights
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final bi = (y * W + x) * 3;
        final luma = 0.2126 * norm[bi] + 0.7152 * norm[bi + 1] + 0.0722 * norm[bi + 2];

        // Shadow weight (strongest below 0.35 luma)
        final shadowW = math.pow((1.0 - luma / 0.35).clamp(0.0, 1.0), 1.5).toDouble();
        // Midtone weight (peaks at 0.5)
        final midW = math.pow((1.0 - (luma - 0.5).abs() / 0.35).clamp(0.0, 1.0), 1.5).toDouble();

        // 2. Shadow teal push (R-, G+, B-)
        norm[bi]     = (norm[bi]     + (-0.080) * shadowW).clamp(0, 1);
        norm[bi + 1] = (norm[bi + 1] + ( 0.095) * shadowW).clamp(0, 1);
        norm[bi + 2] = (norm[bi + 2] + (-0.040) * shadowW).clamp(0, 1);

        // 3. Midtone warmth (G+ push)
        norm[bi]     = (norm[bi]     + 0.015 * midW).clamp(0, 1);
        norm[bi + 1] = (norm[bi + 1] + 0.035 * midW).clamp(0, 1);
        norm[bi + 2] = (norm[bi + 2] - 0.050 * midW).clamp(0, 1);

        // Write back as 0-255
        arr[bi]     = norm[bi]     * 255;
        arr[bi + 1] = norm[bi + 1] * 255;
        arr[bi + 2] = norm[bi + 2] * 255;
      }
    }

    return _fromFloat(arr, W, H);
  }

  // ── Style: Retro Warm ─────────────────────────────────────

  img.Image _styleRetroWarm(img.Image src) {
    final W = src.width;
    final H = src.height;
    var arr = _toFloat(src);
    final norm = Float64List(arr.length);

    const shadowLift = 20.0 / 255.0;
    for (int i = 0; i < arr.length; i++) {
      norm[i] = arr[i] / 255.0 * (1.0 - shadowLift) + shadowLift;
    }

    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final bi = (y * W + x) * 3;
        final luma = 0.2126 * norm[bi] + 0.7152 * norm[bi + 1] + 0.0722 * norm[bi + 2];

        final shadowW = math.pow((1.0 - luma / 0.35).clamp(0.0, 1.0), 1.5).toDouble();
        final midW    = math.pow((1.0 - (luma - 0.5).abs() / 0.35).clamp(0.0, 1.0), 1.5).toDouble();

        // Shadow: dark olive/teal push
        norm[bi]     = (norm[bi]     - 0.070 * shadowW).clamp(0, 1);
        norm[bi + 1] = (norm[bi + 1] + 0.085 * shadowW).clamp(0, 1);
        norm[bi + 2] = (norm[bi + 2] - 0.030 * shadowW).clamp(0, 1);

        // Midtone: warm amber
        norm[bi]     = (norm[bi]     + 0.050 * midW).clamp(0, 1);
        norm[bi + 1] = (norm[bi + 1] + 0.025 * midW).clamp(0, 1);
        norm[bi + 2] = (norm[bi + 2] - 0.080 * midW).clamp(0, 1);

        arr[bi]     = norm[bi]     * 255;
        arr[bi + 1] = norm[bi + 1] * 255;
        arr[bi + 2] = norm[bi + 2] * 255;
      }
    }

    arr = _addChromaticAberration(arr, W, H, 2);
    arr = _addFilmGrain(arr, 14.0);
    arr = _addVignette(arr, W, H, 0.35);
    return _fromFloat(arr, W, H);
  }

  // ── Style: Cinematic (Teal & Orange) ─────────────────────

  img.Image _styleCinematic(img.Image src) {
    var arr = _toFloat(src);
    for (int i = 0; i < arr.length; i += 3) {
      final r = arr[i], b = arr[i + 2];
      if (b < 80) arr[i + 2] = (b * 1.2).clamp(0, 255);  // teal shadows
      if (r > 180) arr[i]    = (r * 1.15).clamp(0, 255); // orange highlights
    }
    arr = _addVignette(arr, src.width, src.height, 0.25);
    return _fromFloat(arr, src.width, src.height);
  }

  // ── Style: Glitch ─────────────────────────────────────────

  img.Image _styleGlitch(img.Image src) {
    var arr = _toFloat(src);
    arr = _addChromaticAberration(arr, src.width, src.height, 8);
    final rng = math.Random();
    final H = src.height;
    final W = src.width;
    final numGlitches = 3 + rng.nextInt(5);
    for (int _ = 0; _ < numGlitches; _++) {
      final y = rng.nextInt(H - 5);
      final offset = (rng.nextInt(40) - 20);
      for (int dy = 0; dy < 3; dy++) {
        final srcRow = Float64List(W * 3);
        final rowStart = (y + dy) * W * 3;
        srcRow.setAll(0, arr.sublist(rowStart, rowStart + W * 3));
        for (int x = 0; x < W; x++) {
          final srcX = (x - offset).clamp(0, W - 1);
          arr[rowStart + x * 3]     = srcRow[srcX * 3];
          arr[rowStart + x * 3 + 1] = srcRow[srcX * 3 + 1];
          arr[rowStart + x * 3 + 2] = srcRow[srcX * 3 + 2];
        }
      }
    }
    return _fromFloat(arr, W, H);
  }

  // ── Style: Cyberpunk ──────────────────────────────────────

  img.Image _styleCyberpunk(img.Image src) {
    var arr = _toFloat(src);
    for (int i = 0; i < arr.length; i += 3) {
      arr[i + 2] = (arr[i + 2] * 1.3).clamp(0, 255); // B++
      arr[i]     = (arr[i]     * 1.1).clamp(0, 255); // R+
      // High contrast
      arr[i]     = ((arr[i]     - 128) * 1.2 + 128).clamp(0, 255);
      arr[i + 1] = ((arr[i + 1] - 128) * 1.2 + 128).clamp(0, 255);
      arr[i + 2] = ((arr[i + 2] - 128) * 1.2 + 128).clamp(0, 255);
    }
    arr = _addVignette(arr, src.width, src.height, 0.5);
    arr = _addChromaticAberration(arr, src.width, src.height, 2);
    return _fromFloat(arr, src.width, src.height);
  }

  // ── Common Effects ────────────────────────────────────────

  Float64List _addChromaticAberration(Float64List arr, int W, int H, int strength) {
    if (strength == 0) return arr;
    final s = strength.abs();
    final result = Float64List.fromList(arr);

    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final di = (y * W + x) * 3;
        // Red channel: shift right (x + s)
        final rxSrc = (x - s).clamp(0, W - 1);
        result[di]     = arr[(y * W + rxSrc) * 3];
        // Blue channel: shift left (x - s)
        final bxSrc = (x + s).clamp(0, W - 1);
        result[di + 2] = arr[(y * W + bxSrc) * 3 + 2];
      }
    }
    return result;
  }

  Float64List _addFilmGrain(Float64List arr, double intensity) {
    final rng = math.Random();
    final result = Float64List(arr.length);
    for (int i = 0; i < arr.length; i++) {
      // Box-Muller Gaussian approximation
      final u1 = rng.nextDouble();
      final u2 = rng.nextDouble();
      final grain = intensity * math.sqrt(-2.0 * math.log(u1 + 1e-8)) * math.cos(2 * math.pi * u2);
      result[i] = (arr[i] + grain).clamp(0, 255);
    }
    return result;
  }

  Float64List _addVignette(Float64List arr, int W, int H, double strength) {
    final result = Float64List(arr.length);
    final cx = W / 2.0;
    final cy = H / 2.0;

    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final dx = (x - cx) / cx;
        final dy = (y - cy) / cy;
        final dist = math.sqrt(dx * dx + dy * dy).clamp(0.0, 1.0);
        final mask = (1.0 - dist * strength).clamp(0.0, 1.0);
        final bi = (y * W + x) * 3;
        result[bi]     = (arr[bi]     * mask).clamp(0, 255);
        result[bi + 1] = (arr[bi + 1] * mask).clamp(0, 255);
        result[bi + 2] = (arr[bi + 2] * mask).clamp(0, 255);
      }
    }
    return result;
  }

  // ── Image ↔ Float64 conversion ────────────────────────────

  Float64List _toFloat(img.Image image) {
    final data = Float64List(image.width * image.height * 3);
    int i = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        data[i++] = p.r.toDouble();
        data[i++] = p.g.toDouble();
        data[i++] = p.b.toDouble();
      }
    }
    return data;
  }

  img.Image _fromFloat(Float64List data, int W, int H) {
    final out = img.Image(width: W, height: H, numChannels: 3);
    int i = 0;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        out.setPixelRgb(x, y, data[i].round(), data[i + 1].round(), data[i + 2].round());
        i += 3;
      }
    }
    return out;
  }
}
