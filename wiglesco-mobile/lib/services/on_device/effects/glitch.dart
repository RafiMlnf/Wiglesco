import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'utils.dart';

img.Image applyGlitch(img.Image src) {
  var arr = EffectUtils.toFloat(src);
  arr = EffectUtils.addChromaticAberration(arr, src.width, src.height, 8);
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
        arr[rowStart + x * 3] = srcRow[srcX * 3];
        arr[rowStart + x * 3 + 1] = srcRow[srcX * 3 + 1];
        arr[rowStart + x * 3 + 2] = srcRow[srcX * 3 + 2];
      }
    }
  }
  return EffectUtils.fromFloat(arr, W, H);
}
