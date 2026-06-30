import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Nostalgic Filter — Authentic 35mm Film Emulation
//
// Research basis:
//   Film cameras produce:
//   1. Lifted shadow base (chemical fog), not pure black
//   2. S-curve response: shadows slightly crushed, highlights roll off softly
//   3. Per-channel color bias depending on film stock + lighting
//   4. Luminance-weighted grain (more visible in mid-tones, less in shadows)
//   5. Halation: a soft warm bleed around ONLY bright highlights (≥200/255)
//      — very subtle, max 8-12% bleed into surrounding pixels
//   6. Soft global dreamy quality — box blur approximates slow film/soft lens
//   7. Lens softness increases toward edges (lens aberration)
//   8. Film base fog overlay (gentle uniform haze, not the same as vignette)
//
// MODE ANALYSIS:
//   DAY: Expired color negative (Kodak Gold/Fuji C200 expired)
//     - Yellow-green cast in shadows, warm lifted mids
//     - Moderate contrast, slight desaturation
//     - Dust & scratches visible, light grain
//
//   GOLDEN: Sunset on color negative (Kodak Portra 400 / Ultramax)
//     - Deep teal shadows, amber-orange midtones, blown cream highlights
//     - High contrast, strong warm split-tone
//     - Lens flare streak from sun source (subtle — NOT cartoon glow)
//
//   NIGHT: Low-light city on ISO800+ film (Kodak ColorPlus push, Fuji 800Z)
//     - Near-black shadows, pink-lavender cast in sky/highlights
//     - Heavy grain (push-processed), strong soft blur (wide aperture)
//     - Warm light sources (street lamps, brake lights stay warm)
//     - Smooth atmospheric fade overlay — NOT a hard vignette circle
// ─────────────────────────────────────────────────────────────────────────────

enum _TimeOfDay { day, golden, night }

img.Image applyNostalgicEffect(
    img.Image src, int seed, String timeOfDay, {bool filmBurn = false}) {
  final W = src.width;
  final H = src.height;
  final rng =
      math.Random(seed == 0 ? DateTime.now().millisecondsSinceEpoch : seed);

  final srcArr = EffectUtils.toFloat(src);
  var canvas = Float64List.fromList(srcArr);

  // Map time string to enum
  final _TimeOfDay time;
  switch (timeOfDay) {
    case 'golden':
      time = _TimeOfDay.golden;
    case 'night':
      time = _TimeOfDay.night;
    default:
      time = _TimeOfDay.day;
  }

  // ── Randomised variation per-render (controls re-generate feel) ───────────
  final double jitter = rng.nextDouble(); // 0.0–1.0 for variation

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Film Base Fog (lifted blacks, chemical base)
  //   Real film never goes to pure black; there's a chemical base density.
  //   We lift the shadow floor slightly without touching highlights.
  // ─────────────────────────────────────────────────────────────────────────
  final double baseFog;
  switch (time) {
    case _TimeOfDay.day:
      baseFog = 14.0 + jitter * 8.0; // Expired film has higher base fog
    case _TimeOfDay.golden:
      baseFog = 9.0 + jitter * 6.0;
    case _TimeOfDay.night:
      baseFog = 5.0 + jitter * 4.0; // Night: minimal fog, deep blacks
  }
  // Apply only to shadow region (pixels below 128), taper off toward mids
  for (int i = 0; i < canvas.length; i += 3) {
    for (int c = 0; c < 3; c++) {
      final double v = canvas[i + c];
      final double t = (1.0 - (v / 200.0)).clamp(0.0, 1.0);
      canvas[i + c] = (v + baseFog * t).clamp(0.0, 255.0);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Split-tone Color Grading (shadow / mid / highlight zones)
  //   Real film stocks have distinct color biases per zone:
  //   shadow bias (D-min color of film base) vs highlight bias (D-max shift)
  // ─────────────────────────────────────────────────────────────────────────
  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      final int bi = (y * W + x) * 3;
      double r = canvas[bi] / 255.0;
      double g = canvas[bi + 1] / 255.0;
      double b = canvas[bi + 2] / 255.0;
      final double L = 0.299 * r + 0.587 * g + 0.114 * b;

      // Zone weights (smooth, non-overlapping bands)
      final double sw = _smoothstep(0.0, 0.35, 1.0 - L); // shadows
      final double hw = _smoothstep(0.0, 0.35, L - 0.65); // highlights
      final double mw = (1.0 - sw - hw).clamp(0.0, 1.0); // midtones

      switch (time) {
        case _TimeOfDay.day:
          // Expired Kodak Gold: yellow-green shadow cast, warm lifted mids
          // Shadows: reduce R slightly, boost G, slightly cut B (green-yellow)
          // Highlights: warm cream push (R+G lift, B neutral)
          r = (r - 0.05 * sw + 0.03 * mw + 0.04 * hw).clamp(0.0, 1.0);
          g = (g + 0.07 * sw + 0.04 * mw + 0.02 * hw).clamp(0.0, 1.0);
          b = (b - 0.03 * sw - 0.04 * mw - 0.02 * hw).clamp(0.0, 1.0);

        case _TimeOfDay.golden:
          // Kodak Portra sunset: deep teal-green shadows, amber mids, cream highs
          // Classic split: cool shadows / warm highlights
          r = (r - 0.04 * sw + 0.09 * mw + 0.10 * hw).clamp(0.0, 1.0);
          g = (g + 0.04 * sw + 0.03 * mw + 0.01 * hw).clamp(0.0, 1.0);
          b = (b - 0.06 * sw - 0.07 * mw - 0.06 * hw).clamp(0.0, 1.0);

        case _TimeOfDay.night:
          // Kodak ColorPlus pushed: deep neutral-warm shadows, pink sky highlights
          // Shadows stay near-neutral (no teal), highlights shift pink-lavender
          r = (r + 0.00 * sw + 0.01 * mw + 0.07 * hw).clamp(0.0, 1.0);
          g = (g - 0.01 * sw + 0.00 * mw - 0.04 * hw).clamp(0.0, 1.0);
          b = (b + 0.01 * sw + 0.02 * mw + 0.09 * hw).clamp(0.0, 1.0);
      }

      canvas[bi] = r * 255.0;
      canvas[bi + 1] = g * 255.0;
      canvas[bi + 2] = b * 255.0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — Film S-Curve Contrast + Saturation
  //   Film's characteristic curve: gentle toe (shadows), steep mid, soft shoulder
  //   We approximate this as: contrast lift + soft highlight rolloff
  // ─────────────────────────────────────────────────────────────────────────
  final double contrastMult;
  final double satMult;
  switch (time) {
    case _TimeOfDay.day:
      contrastMult = 1.10 + jitter * 0.12;
      satMult = 0.65 + jitter * 0.15; // desaturated (expired film)
    case _TimeOfDay.golden:
      contrastMult = 1.18 + jitter * 0.14;
      satMult = 0.70 + jitter * 0.15; // warm channels preserved
    case _TimeOfDay.night:
      contrastMult = 1.25 + jitter * 0.15;
      satMult = 0.58 + jitter * 0.18; // mostly desaturated, lights stay warm
  }

  for (int i = 0; i < canvas.length; i += 3) {
    double r = canvas[i];
    double g = canvas[i + 1];
    double b = canvas[i + 2];

    // S-curve contrast around midpoint 128
    r = ((r - 128.0) * contrastMult + 128.0).clamp(0.0, 255.0);
    g = ((g - 128.0) * contrastMult + 128.0).clamp(0.0, 255.0);
    b = ((b - 128.0) * contrastMult + 128.0).clamp(0.0, 255.0);

    // Saturation
    final double luma = 0.299 * r + 0.587 * g + 0.114 * b;
    r = (luma + (r - luma) * satMult).clamp(0.0, 255.0);
    g = (luma + (g - luma) * satMult).clamp(0.0, 255.0);
    b = (luma + (b - luma) * satMult).clamp(0.0, 255.0);

    canvas[i] = r;
    canvas[i + 1] = g;
    canvas[i + 2] = b;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 4 — Global Soft Blur (film/lens softness)
  //   Real analog cameras have softer overall rendering than digital.
  //   Night mode is heavier (wide aperture + slow film).
  // ─────────────────────────────────────────────────────────────────────────
  final double blurR;
  switch (time) {
    case _TimeOfDay.night:
      blurR = 1.5 + jitter * 1.0;
    case _TimeOfDay.golden:
      blurR = 0.9 + jitter * 0.6;
    case _TimeOfDay.day:
      blurR = 0.7 + jitter * 0.5;
  }
  canvas = _separableBoxBlur(canvas, W, H, blurR);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 5 — Edge Lens Softness
  //   Film lenses are softer at the edges due to aberrations.
  //   This is a position-based jitter blur that only activates outward.
  // ─────────────────────────────────────────────────────────────────────────
  canvas = _lensEdgeSoftness(canvas, W, H, rng, 0.48, 6.0);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 6 — Luminance-weighted Film Grain
  //   Real grain: most visible in mid-tones, less in dense shadows/highlights.
  //   Chromatic noise simulates color grain from film dye layers.
  // ─────────────────────────────────────────────────────────────────────────
  final double grainAmt;
  switch (time) {
    case _TimeOfDay.night:
      grainAmt = 65.0 + jitter * 25.0;
    case _TimeOfDay.golden:
      grainAmt = 48.0 + jitter * 20.0;
    case _TimeOfDay.day:
      grainAmt = 35.0 + jitter * 15.0;
  }
  canvas = _filmGrain(canvas, grainAmt, rng);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 6b — Organic Grunge Overlay (all modes)
  //   Large-scale texture: random blotch clusters + horizontal transport bands.
  //   Changes completely with each seed — gives the "randomize" character.
  // ─────────────────────────────────────────────────────────────────────────
  canvas = _grungeOverlay(canvas, W, H, rng, time);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 7 — Dust, Scratches and Hair Fibers (film transport artifacts)
  // ─────────────────────────────────────────────────────────────────────────
  canvas = _dustAndScratches(canvas, W, H, rng);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 8 — Bayer Pattern Micro-texture (sensor-less simulation via RGB bias)
  // ─────────────────────────────────────────────────────────────────────────
  canvas = _bayerMicroTexture(canvas, W, H, rng);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 9 — Corner Fade / Atmospheric Overlay (mode-dependent)
  //
  //   DAY/GOLDEN: Classic lens vignette — gentle radial darkening at corners
  //   NIGHT: Smooth atmospheric overlay — NOT a vignette circle.
  //     The shadow areas naturally appear dark from contrast; we add only a
  //     very wide, soft atmosphere fade that reduces brightness uniformly
  //     toward edges WITHOUT creating the typical circular vignette look.
  //     Implemented as: screen-space gradient with low power and wide radius.
  // ─────────────────────────────────────────────────────────────────────────
  switch (time) {
    case _TimeOfDay.day:
      canvas = _softVignette(canvas, W, H, 0.35 + jitter * 0.10);
    case _TimeOfDay.golden:
      canvas = _softVignette(canvas, W, H, 0.40 + jitter * 0.12);
    case _TimeOfDay.night:
      // Wide, smooth atmospheric fade — not a sharp vignette
      canvas = _atmosphericFade(canvas, W, H, 0.28 + jitter * 0.12);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10 — Film Halation (ONLY for Day/Golden)
  //   Real halation: bright light bleeds through film base, creating a soft
  //   warm (reddish-orange) glow around only VERY bright sources.
  //   Radius: small (3–5% of frame). Intensity: max 8–12%. Subtle.
  //   Night: no halation pass — light sources stay warm from tone grading.
  // ─────────────────────────────────────────────────────────────────────────
  if (time == _TimeOfDay.day || time == _TimeOfDay.golden) {
    canvas = _filmHalation(canvas, W, H, time, jitter);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 11 — Golden Lens Flare streak (Golden mode only)
  //   A directional light leak / streak from the sun source — subtle line,
  //   not a large circular glow blob.
  // ─────────────────────────────────────────────────────────────────────────
  if (time == _TimeOfDay.golden) {
    canvas = _sunStreak(canvas, W, H, rng, jitter);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 12 — Chromatic Aberration (lateral color fringing)
  // ─────────────────────────────────────────────────────────────────────────
  canvas = EffectUtils.addChromaticAberration(canvas, W, H, 2);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 13 — Film Burn / Light Leak (optional, user-controlled)
  //   Simulates film exposed to light — warm orange/red light leaks at
  //   random edges/corners. Pattern changes every seed.
  // ─────────────────────────────────────────────────────────────────────────
  if (filmBurn) {
    canvas = _filmBurnOverlay(canvas, W, H, rng);
  }

  return EffectUtils.fromFloat(canvas, W, H);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

double _smoothstep(double edge0, double edge1, double x) {
  final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// ── Separable Box Blur (O(W*H) regardless of radius) ─────────────────────────
Float64List _separableBoxBlur(Float64List arr, int W, int H, double sigma) {
  if (sigma < 0.5) return arr;
  final int r = sigma.round().clamp(1, 8);

  final Float64List tmp = Float64List(arr.length);
  // Horizontal
  for (int y = 0; y < H; y++) {
    for (int c = 0; c < 3; c++) {
      double sum = 0;
      int cnt = 0;
      for (int x = 0; x < r && x < W; x++) {
        sum += arr[(y * W + x) * 3 + c];
        cnt++;
      }
      for (int x = 0; x < W; x++) {
        if (x + r < W) {
          sum += arr[(y * W + x + r) * 3 + c];
          cnt++;
        }
        if (x - r - 1 >= 0) {
          sum -= arr[(y * W + x - r - 1) * 3 + c];
          cnt--;
        }
        tmp[(y * W + x) * 3 + c] = sum / cnt;
      }
    }
  }

  // Vertical
  final Float64List out = Float64List(arr.length);
  for (int x = 0; x < W; x++) {
    for (int c = 0; c < 3; c++) {
      double sum = 0;
      int cnt = 0;
      for (int y = 0; y < r && y < H; y++) {
        sum += tmp[(y * W + x) * 3 + c];
        cnt++;
      }
      for (int y = 0; y < H; y++) {
        if (y + r < H) {
          sum += tmp[((y + r) * W + x) * 3 + c];
          cnt++;
        }
        if (y - r - 1 >= 0) {
          sum -= tmp[((y - r - 1) * W + x) * 3 + c];
          cnt--;
        }
        out[(y * W + x) * 3 + c] = sum / cnt;
      }
    }
  }
  return out;
}

// ── Edge Lens Softness (blur increases outward from center) ───────────────────
Float64List _lensEdgeSoftness(Float64List arr, int W, int H, math.Random rng,
    double startFraction, double maxJitter) {
  final result = Float64List(arr.length);
  final double cx = W * 0.5, cy = H * 0.5;
  final double maxD = math.sqrt(cx * cx + cy * cy);
  for (int y = 0; y < H; y++) {
    final double dy = y - cy;
    for (int x = 0; x < W; x++) {
      final double dx = x - cx;
      final double norm = (math.sqrt(dx * dx + dy * dy) / maxD).clamp(0.0, 1.0);
      final int idx = (y * W + x) * 3;
      if (norm > startFraction) {
        final double jAmt = (norm - startFraction) / (1.0 - startFraction) * maxJitter;
        final int bx = (x + (rng.nextDouble() - 0.5) * jAmt).round().clamp(0, W - 1);
        final int by = (y + (rng.nextDouble() - 0.5) * jAmt).round().clamp(0, H - 1);
        final int bIdx = (by * W + bx) * 3;
        result[idx] = arr[bIdx];
        result[idx + 1] = arr[bIdx + 1];
        result[idx + 2] = arr[bIdx + 2];
      } else {
        result[idx] = arr[idx];
        result[idx + 1] = arr[idx + 1];
        result[idx + 2] = arr[idx + 2];
      }
    }
  }
  return result;
}

// ── Luminance-weighted Film Grain ─────────────────────────────────────────────
// Highly visible grain, present in all areas but slightly masked in extreme shadows/highlights.
Float64List _filmGrain(Float64List arr, double amount, math.Random rng) {
  final result = Float64List(arr.length);
  for (int i = 0; i < arr.length; i += 3) {
    final double r = arr[i], g = arr[i + 1], b = arr[i + 2];
    final double luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
    // Grain mask: less restrictive so grain is visible in shadows/highlights
    final double grainMask = 0.45 + 0.55 * (1.0 - (2.0 * luma - 1.0).abs());
    final double baseNoise = (rng.nextDouble() - 0.5) * amount * grainMask;
    // Chromatic component — simulate vintage color grain dye layers
    result[i] = (r + baseNoise + (rng.nextDouble() - 0.5) * amount * 0.7 * grainMask)
        .clamp(0, 255);
    result[i + 1] = (g + baseNoise +
            (rng.nextDouble() - 0.5) * amount * 0.7 * grainMask)
        .clamp(0, 255);
    result[i + 2] = (b + baseNoise +
            (rng.nextDouble() - 0.5) * amount * 0.7 * grainMask)
        .clamp(0, 255);
  }
  return result;
}

// ── Dust, Hair Scratches ──────────────────────────────────────────────────────
Float64List _dustAndScratches(Float64List arr, int W, int H, math.Random rng) {
  final result = Float64List.fromList(arr);

  // Large-scale visible dust & hair fibers
  final int numDust = 30 + rng.nextInt(35);
  for (int i = 0; i < numDust; i++) {
    final int px = rng.nextInt(W), py = rng.nextInt(H);
    final double val = rng.nextBool() ? 10.0 : 240.0; // very dark or very bright
    final double op = 0.65 + rng.nextDouble() * 0.35; // high opacity
    final int size = rng.nextInt(3) + 1; // 1 to 3 pixels wide/tall dust speckles

    for (int dy = 0; dy < size; dy++) {
      for (int dx = 0; dx < size; dx++) {
        final int tx = (px + dx).clamp(0, W - 1);
        final int ty = (py + dy).clamp(0, H - 1);
        final int idx = (ty * W + tx) * 3;
        for (int c = 0; c < 3; c++) {
          result[idx + c] = (result[idx + c] * (1 - op) + val * op).clamp(0, 255);
        }
      }
    }
  }

  // Draw 2 to 5 long hair-like transport scratches across the film frame
  final int numScratches = 2 + rng.nextInt(4);
  for (int i = 0; i < numScratches; i++) {
    _bresenhamScratch(result, W, H, rng);
  }

  return result;
}

void _bresenhamScratch(Float64List arr, int W, int H, math.Random rng) {
  int x0 = rng.nextInt(W), y0 = rng.nextInt(H);
  final int len = 50 + rng.nextInt(120);
  final double angle = rng.nextDouble() * 2 * math.pi;
  int x1 = (x0 + math.cos(angle) * len).round().clamp(0, W - 1);
  int y1 = (y0 + math.sin(angle) * len).round().clamp(0, H - 1);
  final double op = 0.45 + rng.nextDouble() * 0.35; // very visible scratches
  final double val = rng.nextBool() ? 15.0 : 235.0;

  int dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
  int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  int err = dx - dy;
  while (true) {
    if (x0 >= 0 && x0 < W && y0 >= 0 && y0 < H) {
      final int idx = (y0 * W + x0) * 3;
      // Slightly wider lines to ensure visibility
      for (int offset = 0; offset <= 1; offset++) {
        final int targetIdx = (idx + offset * 3).clamp(0, arr.length - 3);
        for (int c = 0; c < 3; c++) {
          arr[targetIdx + c] = (arr[targetIdx + c] * (1 - op) + val * op).clamp(0, 255);
        }
      }
    }
    if (x0 == x1 && y0 == y1) break;
    int e2 = 2 * err;
    if (e2 > -dy) {
      err -= dy;
      x0 += sx;
    }
    if (e2 < dx) {
      err += dx;
      y0 += sy;
    }
  }
}

// ── Bayer Micro-Texture ───────────────────────────────────────────────────────
Float64List _bayerMicroTexture(Float64List arr, int W, int H, math.Random rng) {
  final result = Float64List.fromList(arr);
  final double gs = 0.018 + rng.nextDouble() * 0.022;
  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      final int idx = (y * W + x) * 3;
      final double f = 1.0 - gs * ((x % 2 == 0 ? 1.0 : 0.0) + (y % 2 == 0 ? 1.0 : 0.0));
      result[idx] = (result[idx] * f).clamp(0, 255);
      result[idx + 1] = (result[idx + 1] * f).clamp(0, 255);
      result[idx + 2] = (result[idx + 2] * f).clamp(0, 255);
    }
  }
  return result;
}

// ── Soft Radial Vignette (lens optics — day/golden) ───────────────────────────
// Standard cosine falloff from center, darkening corners.
Float64List _softVignette(Float64List arr, int W, int H, double strength) {
  final result = Float64List(arr.length);
  final double cx = W * 0.5, cy = H * 0.5;
  final double maxD = math.sqrt(cx * cx + cy * cy);
  for (int y = 0; y < H; y++) {
    final double dy = y - cy;
    for (int x = 0; x < W; x++) {
      final double norm = math.sqrt((x - cx) * (x - cx) + dy * dy) / maxD;
      // Smooth falloff: t = norm^2, darkening only after 0.5 normalized distance
      final double t = math.pow((norm).clamp(0.0, 1.0), 2.0).toDouble();
      final double fade = (1.0 - strength * t).clamp(0.0, 1.0);
      final int idx = (y * W + x) * 3;
      result[idx] = (arr[idx] * fade).clamp(0, 255);
      result[idx + 1] = (arr[idx + 1] * fade).clamp(0, 255);
      result[idx + 2] = (arr[idx + 2] * fade).clamp(0, 255);
    }
  }
  return result;
}

// ── Atmospheric Fade (night mode only — NOT a vignette) ──────────────────────
// Applies a very wide, barely-perceptible ambient darkening toward edges.
// Uses a low power (0.4) making it feel like atmospheric haze, not lens vignette.
// The key difference from vignette: much lower power → slower falloff,
// larger effective radius, looks like environment ambiance not lens artifact.
Float64List _atmosphericFade(Float64List arr, int W, int H, double strength) {
  final result = Float64List(arr.length);
  final double cx = W * 0.5, cy = H * 0.5;
  final double maxD = math.sqrt(cx * cx + cy * cy);
  for (int y = 0; y < H; y++) {
    final double dy = y - cy;
    for (int x = 0; x < W; x++) {
      final double norm = math.sqrt((x - cx) * (x - cx) + dy * dy) / maxD;
      // Low power (0.4) = very gradual transition — atmospheric feel not vignette
      final double t = math.pow(norm.clamp(0.0, 1.0), 0.4).toDouble();
      final double fade = (1.0 - strength * t).clamp(0.0, 1.0);
      final int idx = (y * W + x) * 3;
      result[idx] = (arr[idx] * fade).clamp(0, 255);
      result[idx + 1] = (arr[idx + 1] * fade).clamp(0, 255);
      result[idx + 2] = (arr[idx + 2] * fade).clamp(0, 255);
    }
  }
  return result;
}

// ── Film Halation (subtle warm bleed around bright highlights only) ───────────
// Only activates on pixels already above threshold (luma ≥ 0.78).
// Max intensity: 9-12% warm bleed. Very soft falloff radius.
Float64List _filmHalation(
    Float64List arr, int W, int H, _TimeOfDay time, double jitter) {
  // First blur a threshold mask to get the halation halo
  // Identify bright pixels
  final Float64List halo = Float64List(W * H); // single-channel halo mask
  for (int i = 0; i < arr.length; i += 3) {
    final double luma = (0.299 * arr[i] + 0.587 * arr[i + 1] + 0.114 * arr[i + 2]) / 255.0;
    halo[i ~/ 3] = luma > 0.78 ? (luma - 0.78) / 0.22 : 0.0;
  }

  // Blur the halo mask (spread the light bleed)
  final int hr = 8; // halation radius in pixels
  final Float64List haloBlur = Float64List(W * H);
  // Horizontal
  final Float64List haloTmp = Float64List(W * H);
  for (int y = 0; y < H; y++) {
    double sum = 0;
    int cnt = 0;
    for (int x = 0; x < hr && x < W; x++) {
      sum += halo[y * W + x];
      cnt++;
    }
    for (int x = 0; x < W; x++) {
      if (x + hr < W) {
        sum += halo[y * W + x + hr];
        cnt++;
      }
      if (x - hr - 1 >= 0) {
        sum -= halo[y * W + x - hr - 1];
        cnt--;
      }
      haloTmp[y * W + x] = sum / cnt;
    }
  }
  for (int x = 0; x < W; x++) {
    double sum = 0;
    int cnt = 0;
    for (int y = 0; y < hr && y < H; y++) {
      sum += haloTmp[y * W + x];
      cnt++;
    }
    for (int y = 0; y < H; y++) {
      if (y + hr < H) {
        sum += haloTmp[(y + hr) * W + x];
        cnt++;
      }
      if (y - hr - 1 >= 0) {
        sum -= haloTmp[(y - hr - 1) * W + x];
        cnt--;
      }
      haloBlur[y * W + x] = sum / cnt;
    }
  }

  // Composite: add warm (reddish-orange) tint weighted by haloBlur
  final double haloPower = 0.09 + jitter * 0.04; // max 9–13% strength
  final result = Float64List.fromList(arr);
  for (int i = 0; i < arr.length; i += 3) {
    final double h = haloBlur[i ~/ 3] * haloPower;
    // Warm bleed: R = 1.0, G = 0.65, B = 0.30 (orange-warm)
    result[i] = (arr[i] + 255 * h * 1.00).clamp(0, 255);
    result[i + 1] = (arr[i + 1] + 255 * h * 0.65).clamp(0, 255);
    result[i + 2] = (arr[i + 2] + 255 * h * 0.30).clamp(0, 255);
  }
  return result;
}

// ── Sun Streak / Light Leak (Golden mode) ────────────────────────────────────
// A directional bright streak from upper area — simulates sun hitting lens.
// Narrow horizontal band with gaussian falloff — NOT a blob.
Float64List _sunStreak(
    Float64List arr, int W, int H, math.Random rng, double jitter) {
  final result = Float64List.fromList(arr);
  // Streak origin (upper portion, random horizontal position)
  final double streakX = W * (0.55 + rng.nextDouble() * 0.35);
  final double streakY = H * (0.02 + rng.nextDouble() * 0.12);
  // Streak extends diagonally
  final double angle = -math.pi / 4 + (rng.nextDouble() - 0.5) * 0.4;
  final int streakLen = (W * (0.30 + jitter * 0.20)).round();
  final double streakWidth = W * 0.025; // narrow beam

  for (int i = 0; i < streakLen; i++) {
    final double t = i / streakLen;
    final double px = streakX + math.cos(angle) * i;
    final double py = streakY + math.sin(angle) * i;
    // Fade along the streak length (brightest at origin)
    final double lenFade = math.pow(1.0 - t, 1.5).toDouble();

    // Perpendicular width
    final int scanW = (streakWidth * 3).round();
    for (int d = -scanW; d <= scanW; d++) {
      final int ix = (px + math.sin(angle) * d).round();
      final int iy = (py - math.cos(angle) * d).round();
      if (ix < 0 || ix >= W || iy < 0 || iy >= H) continue;

      // Gaussian falloff perpendicular to streak
      final double perpFade =
          math.exp(-(d * d) / (2 * streakWidth * streakWidth * 0.3));
      final double glow = lenFade * perpFade * (0.22 + jitter * 0.10);

      final int idx = (iy * W + ix) * 3;
      // Warm white-orange streak
      result[idx] = (result[idx] + 255 * glow * 1.00).clamp(0, 255);
      result[idx + 1] = (result[idx + 1] + 255 * glow * 0.88).clamp(0, 255);
      result[idx + 2] = (result[idx + 2] + 255 * glow * 0.60).clamp(0, 255);
    }
  }
  return result;
}

// ── Organic Grunge Overlay ────────────────────────────────────────────────────
// Adds large-scale organic texture: blotch clusters + horizontal transport bands.
// Different each seed, highly visible and aesthetic.
Float64List _grungeOverlay(
    Float64List arr, int W, int H, math.Random rng, _TimeOfDay time) {
  final result = Float64List.fromList(arr);

  // 1. Horizontal transport banding (noticeable bands of exposure variation)
  //    Simulates uneven film advancement or light leak streaks in old rollers.
  final int bandH = 25 + rng.nextInt(35); // wider bands
  final int totalBands = (H ~/ bandH) + 2;
  final List<double> bandOffsets = List.generate(
    totalBands,
    (index) => (rng.nextDouble() - 0.5) * 16.0 // offset value up to +/- 8 levels
  );

  for (int y = 0; y < H; y++) {
    final int bandIndex = y ~/ bandH;
    if (bandIndex < bandOffsets.length) {
      final double offset = bandOffsets[bandIndex];
      for (int x = 0; x < W; x++) {
        final int idx = (y * W + x) * 3;
        result[idx] = (result[idx] + offset).clamp(0, 255);
        result[idx + 1] = (result[idx + 1] + offset).clamp(0, 255);
        result[idx + 2] = (result[idx + 2] + offset).clamp(0, 255);
      }
    }
  }

  // 2. Random blotch clusters (large soft chemical stain patches of over/under-exposure)
  //    Adds realistic development stain patterns.
  final int numBlotches = 8 + rng.nextInt(12);
  for (int b = 0; b < numBlotches; b++) {
    final double cx = rng.nextDouble() * W;
    final double cy = rng.nextDouble() * H;
    // Larger radius parameters for clear visibility
    final double rx = W * (0.16 + rng.nextDouble() * 0.22);
    final double ry = H * (0.12 + rng.nextDouble() * 0.18);
    // Stronger opacity shifts (22 to 50 levels of color/exposure shift)
    final double delta = (rng.nextBool() ? -1 : 1) * (22.0 + rng.nextDouble() * 28.0);
    // More prominent color shifts (e.g. reddish or bluish stains)
    final double tintR = (rng.nextDouble() - 0.5) * 12.0;
    final double tintB = (rng.nextDouble() - 0.5) * 12.0;

    for (int y = 0; y < H; y++) {
      final double dy = (y - cy) / ry;
      if (dy * dy > 1.0) continue;
      for (int x = 0; x < W; x++) {
        final double dx = (x - cx) / rx;
        final double distSq = dx * dx + dy * dy;
        if (distSq >= 1.0) continue;
        final double t = math.pow(1.0 - distSq, 2.0).toDouble();
        final int idx = (y * W + x) * 3;
        result[idx] = (result[idx] + (delta + tintR) * t).clamp(0, 255);
        result[idx + 1] = (result[idx + 1] + delta * t).clamp(0, 255);
        result[idx + 2] = (result[idx + 2] + (delta + tintB) * t).clamp(0, 255);
      }
    }
  }

  // 3. Vertical transport streak lines (distinct scratch line areas)
  final int numStreaks = 3 + rng.nextInt(4);
  for (int s = 0; s < numStreaks; s++) {
    final int sx = rng.nextInt(W);
    final int sw = 1 + rng.nextInt(3); // 1 to 3 pixels wide streaks
    final double streakDelta = (rng.nextBool() ? -1 : 1) * (14.0 + rng.nextDouble() * 16.0);
    for (int y = 0; y < H; y++) {
      for (int dx = 0; dx < sw; dx++) {
        final int x = (sx + dx).clamp(0, W - 1);
        final int idx = (y * W + x) * 3;
        for (int c = 0; c < 3; c++) {
          result[idx + c] = (result[idx + c] + streakDelta).clamp(0, 255);
        }
      }
    }
  }

  return result;
}

// ── Film Burn / Light Leak Overlay ───────────────────────────────────────────
// Simulates film accidentally exposed to light — warm orange/red/amber zones
// appearing at random edges and corners. Pattern is fully seed-driven.
Float64List _filmBurnOverlay(
    Float64List arr, int W, int H, math.Random rng) {
  final result = Float64List.fromList(arr);

  // Define 8 possible burn origin zones (edges + corners)
  // Each zone: (cx_fraction, cy_fraction) as fraction of W/H
  final List<List<double>> zones = [
    [0.0, 0.0],   // top-left corner
    [1.0, 0.0],   // top-right corner
    [0.0, 1.0],   // bottom-left corner
    [1.0, 1.0],   // bottom-right corner
    [0.5, 0.0],   // top center edge
    [0.5, 1.0],   // bottom center edge
    [0.0, 0.5],   // left center edge
    [1.0, 0.5],   // right center edge
  ];

  // Shuffle and pick 1–3 burn zones
  zones.shuffle(rng);
  final int numBurns = 1 + rng.nextInt(3);

  for (int b = 0; b < numBurns; b++) {
    final double originX = zones[b][0] * W;
    final double originY = zones[b][1] * H;

    // Elliptical burn radius (bigger at corners, narrower at edge centers)
    final bool isCorner = b < 4;
    final double rx = W * (isCorner
        ? 0.25 + rng.nextDouble() * 0.30
        : 0.35 + rng.nextDouble() * 0.25);
    final double ry = H * (isCorner
        ? 0.25 + rng.nextDouble() * 0.28
        : 0.20 + rng.nextDouble() * 0.20);

    // Intensity variation per burn
    final double intensity = 0.45 + rng.nextDouble() * 0.55;

    // Color palette: each burn is slightly different warm tone
    final double colR = 0.90 + rng.nextDouble() * 0.10; // R always near 1
    final double colG = 0.30 + rng.nextDouble() * 0.30; // G varies (orange–amber)
    final double colB = 0.00 + rng.nextDouble() * 0.15; // B near 0 (warm)

    for (int y = 0; y < H; y++) {
      final double dy = (y - originY) / ry;
      final double dySq = dy * dy;
      if (dySq > 1.0) continue;

      for (int x = 0; x < W; x++) {
        final double dx = (x - originX) / rx;
        final double distSq = dx * dx + dySq;
        if (distSq >= 1.0) continue;

        // Smooth falloff: brighter near origin, fades to edge of ellipse
        // Use power 1.0 for organic, non-circular feel
        final double t =
            math.pow((1.0 - distSq), 1.2).toDouble() * intensity;

        // Add slight organic noise to break up clean ellipse
        final double noise = (rng.nextDouble() - 0.3) * 0.15 * t;
        final double burnAmt = (t + noise).clamp(0.0, 1.0);

        final int idx = (y * W + x) * 3;
        // Screen blending: brighter, warm-tinted
        result[idx] =
            (255 - (255 - result[idx]) * (1.0 - colR * burnAmt)).clamp(0, 255);
        result[idx + 1] =
            (255 - (255 - result[idx + 1]) * (1.0 - colG * burnAmt)).clamp(0, 255);
        result[idx + 2] =
            (255 - (255 - result[idx + 2]) * (1.0 - colB * burnAmt)).clamp(0, 255);
      }
    }
  }

  return result;
}

