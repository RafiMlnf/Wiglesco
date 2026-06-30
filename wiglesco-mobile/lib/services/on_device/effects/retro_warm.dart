import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'utils.dart';

img.Image applyRetroWarm(img.Image src) {
  final W = src.width;
  final H = src.height;
  var arr = EffectUtils.toFloat(src);
  final norm = Float64List(arr.length);

  const shadowLift = 20.0 / 255.0;
  for (int i = 0; i < arr.length; i++) {
    norm[i] = arr[i] / 255.0 * (1.0 - shadowLift) + shadowLift;
  }

  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      final bi = (y * W + x) * 3;
      final luma = 0.2126 * norm[bi] +
          0.7152 * norm[bi + 1] +
          0.0722 * norm[bi + 2];

      final shadowW =
          math.pow((1.0 - luma / 0.35).clamp(0.0, 1.0), 1.5).toDouble();
      final midW = math
          .pow((1.0 - (luma - 0.5).abs() / 0.35).clamp(0.0, 1.0), 1.5)
          .toDouble();

      // Shadow: dark olive/teal push
      norm[bi] = (norm[bi] - 0.070 * shadowW).clamp(0, 1);
      norm[bi + 1] = (norm[bi + 1] + 0.085 * shadowW).clamp(0, 1);
      norm[bi + 2] = (norm[bi + 2] - 0.030 * shadowW).clamp(0, 1);

      // Midtone: warm amber
      norm[bi] = (norm[bi] + 0.050 * midW).clamp(0, 1);
      norm[bi + 1] = (norm[bi + 1] + 0.025 * midW).clamp(0, 1);
      norm[bi + 2] = (norm[bi + 2] - 0.080 * midW).clamp(0, 1);

      arr[bi] = norm[bi] * 255;
      arr[bi + 1] = norm[bi + 1] * 255;
      arr[bi + 2] = norm[bi + 2] * 255;
    }
  }

  arr = EffectUtils.addChromaticAberration(arr, W, H, 2);
  arr = EffectUtils.addFilmGrain(arr, 14.0);
  arr = EffectUtils.addVignette(arr, W, H, 0.35);
  return EffectUtils.fromFloat(arr, W, H);
}
