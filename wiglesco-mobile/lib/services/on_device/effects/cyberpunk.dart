import 'package:image/image.dart' as img;
import 'utils.dart';

img.Image applyCyberpunk(img.Image src) {
  var arr = EffectUtils.toFloat(src);
  for (int i = 0; i < arr.length; i += 3) {
    arr[i + 2] = (arr[i + 2] * 1.3).clamp(0, 255); // B++
    arr[i] = (arr[i] * 1.1).clamp(0, 255); // R+
    // High contrast
    arr[i] = ((arr[i] - 128) * 1.2 + 128).clamp(0, 255);
    arr[i + 1] = ((arr[i + 1] - 128) * 1.2 + 128).clamp(0, 255);
    arr[i + 2] = ((arr[i + 2] - 128) * 1.2 + 128).clamp(0, 255);
  }
  arr = EffectUtils.addVignette(arr, src.width, src.height, 0.5);
  arr = EffectUtils.addChromaticAberration(arr, src.width, src.height, 2);
  return EffectUtils.fromFloat(arr, src.width, src.height);
}
