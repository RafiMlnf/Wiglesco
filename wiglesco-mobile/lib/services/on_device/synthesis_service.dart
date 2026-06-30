import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Port of the Python NovelViewSynthesisService._warp_sync()
/// 3D Y-axis rotation + Painter's Algorithm + disocclusion fill.
///
/// Runs in a background Isolate — never blocks UI thread.
class OnDeviceSynthesisService {
  /// Generate [numFrames] parallax frames from [source] image + [depthMap].
  ///
  /// [depthMap] — Float32List of length H×W, values in [0, 1].
  /// Returns list of img.Image frames.
  Future<List<img.Image>> generateFrames({
    required img.Image source,
    required Float32List depthMap,
    required int numFrames,
    required double parallaxStrength,
  }) async {
    final args = _SynthesisArgs(
      sourceBytes: _imageToRgbBytes(source),
      width: source.width,
      height: source.height,
      depthMap: depthMap,
      numFrames: numFrames,
      parallaxStrength: parallaxStrength,
    );

    return Isolate.run(() => _warpSync(args));
  }

  // ── Helpers ────────────────────────────────────────────────

  static Uint8List _imageToRgbBytes(img.Image image) {
    // Convert to raw [R, G, B, R, G, B, ...] bytes
    final bytes = Uint8List(image.width * image.height * 3);
    int i = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        bytes[i++] = p.r.toInt();
        bytes[i++] = p.g.toInt();
        bytes[i++] = p.b.toInt();
      }
    }
    return bytes;
  }

  // ── Core warp algorithm (runs in Isolate) ──────────────────

  static List<img.Image> _warpSync(_SynthesisArgs args) {
    final H = args.height;
    final W = args.width;
    final rawDepth = args.depthMap;
    final strength = args.parallaxStrength;
    final numFrames = args.numFrames;

    // ── 1. Resize depth map from model size (518x518) to match source image (WxH) ──
    final resizedDepth = _resizeDepthMap(rawDepth, 518, 518, W, H);

    // ── 2. Smooth the depth map using a box filter to avoid slicing/tearing artifacts ──
    final smoothedDepth = _blurDepthMap(resizedDepth, W, H);

    // ── 3. Build Z map from depth [same as Python] ───────────────
    // Z = 1.0 + (1.0 - depth) * 1.5   (near = low Z, far = high Z)
    final Z = Float64List(H * W);
    double depthSum = 0;
    for (int i = 0; i < H * W; i++) {
      Z[i] = 1.0 + (1.0 - smoothedDepth[i]) * 1.5;
      depthSum += smoothedDepth[i];
    }

    final depthMean = depthSum / (H * W);
    final zFocus = 1.0 + (1.0 - depthMean) * 1.5;

    // Virtual focal length & center
    final f = math.max(H, W) * 1.2;
    final cx = W / 2.0;
    final cy = H / 2.0;

    // Max rotation angle (radians)
    final maxTheta = 0.06 * strength;

    // Evenly spaced rotation angles
    final thetas = List<double>.generate(
      numFrames,
      (i) => -maxTheta + (2 * maxTheta / (numFrames - 1)) * i,
    );

    return thetas.map((theta) {
      return _warpFrame(
        sourceBytes: args.sourceBytes,
        W: W,
        H: H,
        Z: Z,
        zFocus: zFocus,
        f: f,
        cx: cx,
        cy: cy,
        theta: theta,
        parallaxStrength: strength,
      );
    }).toList();
  }

  static img.Image _warpFrame({
    required Uint8List sourceBytes,
    required int W,
    required int H,
    required Float64List Z,
    required double zFocus,
    required double f,
    required double cx,
    required double cy,
    required double theta,
    required double parallaxStrength,
  }) {
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    // Output canvas + z-buffer for Painter's Algorithm
    final canvas = Uint8List(H * W * 3);
    final zBuffer = Float64List(H * W)..fillRange(0, H * W, double.infinity);

    // ── Forward warp: source pixel → target position ──────────
    for (int y = 0; y < H; y++) {
      final normY = (y - cy) / f;

      for (int x = 0; x < W; x++) {
        final srcIdx = y * W + x;
        final zVal = Z[srcIdx];
        final normX = (x - cx) / f;

        // 3D coordinates
        final x3d = normX * zVal;
        final zRel = zVal - zFocus;

        // 3D Y-axis rotation
        final xRot = x3d * cosT - zRel * sinT;
        final zRot = math.max(x3d * sinT + zRel * cosT + zFocus, 0.1);

        // Project back to 2D
        final xt = (xRot / zRot) * f + cx;
        final yt = (normY * zVal / zRot) * f + cy;

        final ix = xt.round();
        final iy = yt.round();

        if (ix < 0 || ix >= W || iy < 0 || iy >= H) continue;

        final dstIdx = iy * W + ix;

        // Painter's algorithm: closer pixel wins (smaller Z)
        if (zRot < zBuffer[dstIdx]) {
          zBuffer[dstIdx] = zRot;
          final r = sourceBytes[srcIdx * 3];
          final g = sourceBytes[srcIdx * 3 + 1];
          final b = sourceBytes[srcIdx * 3 + 2];
          canvas[dstIdx * 3]     = r;
          canvas[dstIdx * 3 + 1] = g;
          canvas[dstIdx * 3 + 2] = b;
        }
      }
    }

    // ── Fill holes with nearest neighbor ─────────────────────
    final filled = _fillHoles(canvas, zBuffer, W, H);

    // ── Crop border artifacts ─────────────────────────────────
    final cropW = (W * 0.05 * parallaxStrength).toInt().clamp(4, (W * 0.12).toInt());
    final cropH = (H * (cropW / W)).toInt();

    // ── Build output img.Image ────────────────────────────────
    final output = img.Image(width: W, height: H, numChannels: 3);
    for (int y = 0; y < H; y++) {
      // Source y from cropped region, clamped
      final srcY = (cropH + y * (H - 2 * cropH) / H).toInt().clamp(cropH, H - cropH - 1);
      for (int x = 0; x < W; x++) {
        final srcX = (cropW + x * (W - 2 * cropW) / W).toInt().clamp(cropW, W - cropW - 1);
        final si = srcY * W + srcX;
        output.setPixelRgb(x, y, filled[si * 3], filled[si * 3 + 1], filled[si * 3 + 2]);
      }
    }

    return output;
  }

  /// Bilinearly resizes a Float32List depth map from srcW x srcH to dstW x dstH.
  static Float32List _resizeDepthMap(
    Float32List srcDepth,
    int srcW,
    int srcH,
    int dstW,
    int dstH,
  ) {
    final dstDepth = Float32List(dstW * dstH);
    final scaleX = (srcW - 1) / (dstW - 1 == 0 ? 1 : dstW - 1);
    final scaleY = (srcH - 1) / (dstH - 1 == 0 ? 1 : dstH - 1);

    for (int y = 0; y < dstH; y++) {
      final srcY = y * scaleY;
      final y0 = srcY.floor();
      final y1 = math.min(y0 + 1, srcH - 1);
      final dy = srcY - y0;

      for (int x = 0; x < dstW; x++) {
        final srcX = x * scaleX;
        final x0 = srcX.floor();
        final x1 = math.min(x0 + 1, srcW - 1);
        final dx = srcX - x0;

        // Bilinear interpolation values
        final val00 = srcDepth[y0 * srcW + x0];
        final val10 = srcDepth[y0 * srcW + x1];
        final val01 = srcDepth[y1 * srcW + x0];
        final val11 = srcDepth[y1 * srcW + x1];

        final val = (1 - dx) * (1 - dy) * val00 +
            dx * (1 - dy) * val10 +
            (1 - dx) * dy * val01 +
            dx * dy * val11;

        dstDepth[y * dstW + x] = val;
      }
    }
    return dstDepth;
  }

  /// Appends a box blur/smoothing filter to the Float32List depth map.
  /// This mirrors OpenCV's bilateral/Gaussian blur to prevent pixel tearing.
  /// Optimasi: Separable Box Blur (1D horizontal pass lalu 1D vertical pass)
  /// Mengurangi lookup array dari 25x menjadi hanya 10x per piksel.
  static Float64List _blurDepthMap(Float32List depth, int W, int H) {
    final temp = Float32List(W * H);
    final blurred = Float64List(W * H);
    const r = 4; // radius 4 (9x9 filter equivalent) to prevent slicing/tearing glitches

    // Pass 1: Horizontal Box Blur
    for (int y = 0; y < H; y++) {
      final int rowOffset = y * W;
      for (int x = 0; x < W; x++) {
        double sum = 0;
        int count = 0;
        for (int dx = -r; dx <= r; dx++) {
          final nx = x + dx;
          if (nx >= 0 && nx < W) {
            sum += depth[rowOffset + nx];
            count++;
          }
        }
        temp[rowOffset + x] = (sum / count).toDouble();
      }
    }

    // Pass 2: Vertical Box Blur
    for (int y = 0; y < H; y++) {
      final int rowOffset = y * W;
      for (int x = 0; x < W; x++) {
        double sum = 0;
        int count = 0;
        for (int dy = -r; dy <= r; dy++) {
          final ny = y + dy;
          if (ny >= 0 && ny < H) {
            sum += temp[ny * W + x];
            count++;
          }
        }
        blurred[rowOffset + x] = sum / count;
      }
    }

    return blurred;
  }

  /// Fill empty pixels (where z-buffer is still infinity) with nearby color.
  /// Blends 50% from the foreground boundary pixels (min Z) and 50% from the background pixels (max Z)
  /// to create a balanced fill without hard stretch artifacts.
  static Uint8List _fillHoles(Uint8List canvas, Float64List zBuffer, int W, int H) {
    final result = Uint8List.fromList(canvas);
    const searchRadius = 6;

    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final idx = y * W + x;
        if (zBuffer[idx] < double.infinity) continue; // already filled

        int fgIdx = -1;
        int bgIdx = -1;
        double minZ = double.infinity;
        double maxZ = -double.infinity;

        // Search in a window around the empty pixel
        for (int dy = -searchRadius; dy <= searchRadius; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= H) continue;

          for (int dx = -searchRadius; dx <= searchRadius; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= W) continue;

            final ni = ny * W + nx;
            final z = zBuffer[ni];
            if (z < double.infinity) {
              if (z < minZ) {
                minZ = z;
                fgIdx = ni;
              }
              if (z > maxZ) {
                maxZ = z;
                bgIdx = ni;
              }
            }
          }
        }

        if (fgIdx != -1 && bgIdx != -1) {
          // If we found distinct layers (foreground vs background), blend them 50:50
          if (maxZ - minZ > 0.1) {
            result[idx * 3]     = ((canvas[fgIdx * 3] + canvas[bgIdx * 3]) ~/ 2);
            result[idx * 3 + 1] = ((canvas[fgIdx * 3 + 1] + canvas[bgIdx * 3 + 1]) ~/ 2);
            result[idx * 3 + 2] = ((canvas[fgIdx * 3 + 2] + canvas[bgIdx * 3 + 2]) ~/ 2);
          } else {
            // Otherwise, just use the closest (foreground) neighbor
            result[idx * 3]     = canvas[fgIdx * 3];
            result[idx * 3 + 1] = canvas[fgIdx * 3 + 1];
            result[idx * 3 + 2] = canvas[fgIdx * 3 + 2];
          }
        }
      }
    }
    return result;
  }
}

// ── Data transfer object for Isolate ─────────────────────────

class _SynthesisArgs {
  final Uint8List sourceBytes;
  final int width;
  final int height;
  final Float32List depthMap;
  final int numFrames;
  final double parallaxStrength;

  const _SynthesisArgs({
    required this.sourceBytes,
    required this.width,
    required this.height,
    required this.depthMap,
    required this.numFrames,
    required this.parallaxStrength,
  });
}
