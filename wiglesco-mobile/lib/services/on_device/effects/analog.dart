import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'utils.dart';

img.Image applyAnalog(img.Image src) {
  final W = src.width;
  final H = src.height;
  var arr = EffectUtils.toFloat(src);
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
      final luma = 0.2126 * norm[bi] +
          0.7152 * norm[bi + 1] +
          0.0722 * norm[bi + 2];

      // Shadow weight (strongest below 0.35 luma)
      final shadowW =
          math.pow((1.0 - luma / 0.35).clamp(0.0, 1.0), 1.5).toDouble();
      // Midtone weight (peaks at 0.5)
      final midW = math
          .pow((1.0 - (luma - 0.5).abs() / 0.35).clamp(0.0, 1.0), 1.5)
          .toDouble();

      // 2. Shadow teal push (R-, G+, B-)
      norm[bi] = (norm[bi] + (-0.080) * shadowW).clamp(0, 1);
      norm[bi + 1] = (norm[bi + 1] + (0.095) * shadowW).clamp(0, 1);
      norm[bi + 2] = (norm[bi + 2] + (-0.040) * shadowW).clamp(0, 1);

      // 3. Midtone warmth (G+ push)
      norm[bi] = (norm[bi] + 0.015 * midW).clamp(0, 1);
      norm[bi + 1] = (norm[bi + 1] + 0.035 * midW).clamp(0, 1);
      norm[bi + 2] = (norm[bi + 2] - 0.050 * midW).clamp(0, 1);

      // Write back as 0-255
      arr[bi] = norm[bi] * 255;
      arr[bi + 1] = norm[bi + 1] * 255;
      arr[bi + 2] = norm[bi + 2] * 255;
    }
  }

  return EffectUtils.fromFloat(arr, W, H);
}
