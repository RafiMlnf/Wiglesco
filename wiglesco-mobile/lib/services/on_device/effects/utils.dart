import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class EffectUtils {
  static Float64List toFloat(img.Image image) {
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

  static img.Image fromFloat(Float64List data, int W, int H) {
    final out = img.Image(width: W, height: H, numChannels: 3);
    int i = 0;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        out.setPixelRgb(
            x, y, data[i].round(), data[i + 1].round(), data[i + 2].round());
        i += 3;
      }
    }
    return out;
  }

  static Float64List addChromaticAberration(
      Float64List arr, int W, int H, int strength) {
    if (strength == 0) return arr;
    final s = strength.abs();
    final result = Float64List.fromList(arr);

    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final di = (y * W + x) * 3;
        // Red channel: shift right (x + s)
        final rxSrc = (x - s).clamp(0, W - 1);
        result[di] = arr[(y * W + rxSrc) * 3];
        // Blue channel: shift left (x - s)
        final bxSrc = (x + s).clamp(0, W - 1);
        result[di + 2] = arr[(y * W + bxSrc) * 3 + 2];
      }
    }
    return result;
  }

  static Float64List addFilmGrain(Float64List arr, double intensity) {
    final rng = math.Random();
    final result = Float64List(arr.length);
    for (int i = 0; i < arr.length; i++) {
      final u1 = rng.nextDouble();
      final u2 = rng.nextDouble();
      final grain = intensity *
          math.sqrt(-2.0 * math.log(u1 + 1e-8)) *
          math.cos(2 * math.pi * u2);
      result[i] = (arr[i] + grain).clamp(0, 255);
    }
    return result;
  }

  static Float64List addVignette(
      Float64List arr, int W, int H, double strength) {
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
        result[bi] = (arr[bi] * mask).clamp(0, 255);
        result[bi + 1] = (arr[bi + 1] * mask).clamp(0, 255);
        result[bi + 2] = (arr[bi + 2] * mask).clamp(0, 255);
      }
    }
    return result;
  }
}
