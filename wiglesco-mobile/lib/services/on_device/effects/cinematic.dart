import 'package:image/image.dart' as img;
import 'utils.dart';

img.Image applyCinematic(img.Image src) {
  var arr = EffectUtils.toFloat(src);
  for (int i = 0; i < arr.length; i += 3) {
    final r = arr[i], b = arr[i + 2];
    if (b < 80) arr[i + 2] = (b * 1.2).clamp(0, 255); // teal shadows
    if (r > 180) arr[i] = (r * 1.15).clamp(0, 255); // orange highlights
  }
  arr = EffectUtils.addVignette(arr, src.width, src.height, 0.25);
  return EffectUtils.fromFloat(arr, src.width, src.height);
}
