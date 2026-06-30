import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'utils.dart';

/// Applies the CRT + Directional Ghosting + Dreamy Glow Bloom +
/// Phase-shifted RGB Phosphor Panel + Curved Barrel Lens Distortion.
img.Image applyOlise(img.Image src, int seed, double distortion) {
  final W = src.width;
  final H = src.height;

  // ── 1. Setup Random Generator based on the seed ────────────────────────
  final rng = math.Random(seed == 0 ? DateTime.now().millisecondsSinceEpoch : seed);

  final srcArr = EffectUtils.toFloat(src);
  final ghostCanvas = Float64List.fromList(srcArr);

  // ── 2. Randomized Tone Parameters (From seed) ──────────────────────────
  final double contrast = 0.80 + rng.nextDouble() * 0.50;
  final double saturation = 0.45 + rng.nextDouble() * 0.60;
  final double overbrightBoost = 0.35 + rng.nextDouble() * 0.45;

  final double redFactor = 0.70 + rng.nextDouble() * 0.12; 
  final double greenFactor = 1.0 + rng.nextDouble() * 0.05; 
  final double blueFactor = 1.12 + rng.nextDouble() * 0.08; 

  // ── 3. Natural Directional Ghosting (Horizontal & Vertical) ────────────
  final double ghostAngle = rng.nextDouble() * 2 * math.pi;
  final double cosG = math.cos(ghostAngle);
  final double sinG = math.sin(ghostAngle);

  final double shiftDist = (W * 0.024).clamp(8.0, 22.0);
  final int shiftX = (cosG * shiftDist).round();
  final int shiftY = (sinG * shiftDist).round();

  final double freqX = 1.0 / (W * 0.15).clamp(40.0, 150.0);
  final double freqY = 1.0 / (H * 0.15).clamp(40.0, 150.0);

  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      final idx = (y * W + x) * 3;

      final double spatialWeight =
          ((math.sin(x * freqX) * math.cos(y * freqY)) + 1.0) / 2.0;

      if (spatialWeight > 0.15) {
        final sx1 = (x - shiftX).clamp(0, W - 1);
        final sy1 = (y - shiftY).clamp(0, H - 1);
        final idx1 = (sy1 * W + sx1) * 3;

        final sx2 = (x - shiftX * 2).clamp(0, W - 1);
        final sy2 = (y - shiftY * 2).clamp(0, H - 1);
        final idx2 = (sy2 * W + sx2) * 3;

        final double w1 = 0.24 * spatialWeight;
        final double w2 = 0.14 * spatialWeight;
        final double w0 = 1.0 - w1 - w2;

        ghostCanvas[idx] =
            srcArr[idx] * w0 + srcArr[idx1] * w1 + srcArr[idx2] * w2;
        ghostCanvas[idx + 1] = srcArr[idx + 1] * w0 +
            srcArr[idx1 + 1] * w1 +
            srcArr[idx2 + 1] * w2;
        ghostCanvas[idx + 2] = srcArr[idx + 2] * w0 +
            srcArr[idx1 + 2] * w1 +
            srcArr[idx2 + 2] * w2;
      }
    }
  }

  // ── 4. Dreamy Glow / Highlight Bloom (Highlight bleed diffusion) ───────
  final glowCanvas = Float64List.fromList(ghostCanvas);
  final double glowIntensity = 0.28 + rng.nextDouble() * 0.27; 
  final int d = (W * 0.007).clamp(4.0, 10.0).toInt();

  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      final idx = (y * W + x) * 3;

      final xLeft = (x - d).clamp(0, W - 1);
      final xRight = (x + d).clamp(0, W - 1);
      final yUp = (y - d).clamp(0, H - 1);
      final yDown = (y + d).clamp(0, H - 1);

      final idxL = (y * W + xLeft) * 3;
      final idxR = (y * W + xRight) * 3;
      final idxU = (yUp * W + x) * 3;
      final idxD = (yDown * W + x) * 3;

      final double nr = (ghostCanvas[idxL] + ghostCanvas[idxR] + ghostCanvas[idxU] + ghostCanvas[idxD]) / 4.0;
      final double ng = (ghostCanvas[idxL + 1] + ghostCanvas[idxR + 1] + ghostCanvas[idxU + 1] + ghostCanvas[idxD + 1]) / 4.0;
      final double nb = (ghostCanvas[idxL + 2] + ghostCanvas[idxR + 2] + ghostCanvas[idxU + 2] + ghostCanvas[idxD + 2]) / 4.0;

      glowCanvas[idx] = (255 - (255 - ghostCanvas[idx]) * (255 - nr * glowIntensity) / 255).clamp(0, 255);
      glowCanvas[idx + 1] = (255 - (255 - ghostCanvas[idx + 1]) * (255 - ng * glowIntensity) / 255).clamp(0, 255);
      glowCanvas[idx + 2] = (255 - (255 - ghostCanvas[idx + 2]) * (255 - nb * glowIntensity) / 255).clamp(0, 255);
    }
  }

  // ── 5. Apply Tones, Contrast, Saturation & Highlight Exposure ───────────
  for (int i = 0; i < glowCanvas.length; i += 3) {
    double r = glowCanvas[i];
    double g = glowCanvas[i + 1];
    double b = glowCanvas[i + 2];

    // Contrast
    r = ((r - 128) * contrast + 128).clamp(0.0, 255.0);
    g = ((g - 128) * contrast + 128).clamp(0.0, 255.0);
    b = ((b - 128) * contrast + 128).clamp(0.0, 255.0);

    // Saturation
    final double luma = 0.299 * r + 0.587 * g + 0.114 * b;
    r = (luma + (r - luma) * saturation).clamp(0.0, 255.0);
    g = (luma + (g - luma) * saturation).clamp(0.0, 255.0);
    b = (luma + (b - luma) * saturation).clamp(0.0, 255.0);

    // Cool tone shift
    r = (r * redFactor).clamp(0.0, 255.0);
    g = (g * greenFactor).clamp(0.0, 255.0);
    b = (b * blueFactor).clamp(0.0, 255.0);

    // Highlight overbright/bloom
    final double currentLuma = (r + g + b) / 3.0;
    if (currentLuma > 165.0) {
      final double excess = currentLuma - 165.0;
      final double boost = excess * overbrightBoost;
      r = (r + boost).clamp(0.0, 255.0);
      g = (g + boost).clamp(0.0, 255.0);
      b = (b + boost).clamp(0.0, 255.0);
    }

    glowCanvas[i] = r;
    glowCanvas[i + 1] = g;
    glowCanvas[i + 2] = b;
  }

  // ── 6. Phase-Shifted RGB Subpixel Panel & Scanlines Moiré Simulation ───
  // Slant angle generated from the random seed
  final double angleDeg = (rng.nextDouble() * 28.0) - 14.0;
  final double angleRad = angleDeg * math.pi / 180.0;

  final cosA = math.cos(angleRad);
  final sinA = math.sin(angleRad);

  // Randomize panel subpixel frequency (photographed close vs far away)
  final double rgbFreq = 0.65 + rng.nextDouble() * 1.85;

  // Randomize visibility/strength of the panel mask
  final double rgbIntensity = 0.08 + rng.nextDouble() * 0.38;

  // Randomize orthogonal scanlines frequency and intensity
  final double scanlineFreq = 1.1 + rng.nextDouble() * 1.3;
  final double scanlineIntensity = 0.08 + rng.nextDouble() * 0.30;

  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      final idx = (y * W + x) * 3;

      // a. Phase shifted RGB subpixel stripes
      final double rotatedVal = (x * cosA + y * sinA) * rgbFreq;
      final double rMask = 1.0 - rgbIntensity * (1.0 - math.sin(rotatedVal));
      final double gMask = 1.0 - rgbIntensity * (1.0 - math.sin(rotatedVal + 2.0944)); 
      final double bMask = 1.0 - rgbIntensity * (1.0 - math.sin(rotatedVal + 4.1888)); 

      // b. Orthogonal scanlines
      final double scanlineVal = (-x * sinA + y * cosA) * scanlineFreq;
      final double scanlineMask = 1.0 - scanlineIntensity * (1.0 - math.sin(scanlineVal));

      glowCanvas[idx] = (glowCanvas[idx] * rMask * scanlineMask).clamp(0.0, 255.0);
      glowCanvas[idx + 1] = (glowCanvas[idx + 1] * gMask * scanlineMask).clamp(0.0, 255.0);
      glowCanvas[idx + 2] = (glowCanvas[idx + 2] * bMask * scanlineMask).clamp(0.0, 255.0);
    }
  }

  // ── 7. Spherical Barrel Lens Distortion (CRT Bulb Curve) ───────────────
  // Applying distortion AFTER overlaying the grid so that grid/scanlines bend.
  final distortedCanvas = Float64List(W * H * 3);
  final double cx = W / 2.0;
  final double cy = H / 2.0;
  final double maxDistSq = cx * cx + cy * cy;

  final double zoomFactor = 1.0 - (distortion * 0.15);

  for (int y = 0; y < H; y++) {
    final double dy = (y - cy) * zoomFactor;
    for (int x = 0; x < W; x++) {
      final double dx = (x - cx) * zoomFactor;
      final double distSq = (dx * dx + dy * dy) / maxDistSq;

      final double factor = 1.0 + distortion * distSq;

      final double sx = cx + dx * factor;
      final double sy = cy + dy * factor;

      final int isx = sx.round();
      final int isy = sy.round();

      final targetIdx = (y * W + x) * 3;

      if (isx >= 0 && isx < W && isy >= 0 && isy < H) {
        final srcIdx = (isy * W + isx) * 3;
        distortedCanvas[targetIdx] = glowCanvas[srcIdx];
        distortedCanvas[targetIdx + 1] = glowCanvas[srcIdx + 1];
        distortedCanvas[targetIdx + 2] = glowCanvas[srcIdx + 2];
      } else {
        distortedCanvas[targetIdx] = 10;
        distortedCanvas[targetIdx + 1] = 10;
        distortedCanvas[targetIdx + 2] = 12;
      }
    }
  }

  return EffectUtils.fromFloat(distortedCanvas, W, H);
}
