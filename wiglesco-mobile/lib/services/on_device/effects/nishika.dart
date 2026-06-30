import 'package:image/image.dart' as img;
import 'utils.dart';

img.Image applyNishika(img.Image src) {
  var arr = EffectUtils.toFloat(src);
  arr = EffectUtils.addChromaticAberration(arr, src.width, src.height, 3);
  arr = EffectUtils.addFilmGrain(arr, 18.0);
  arr = EffectUtils.addVignette(arr, src.width, src.height, 0.4);
  // Warm shift: R*1.04, B*0.96
  for (int i = 0; i < arr.length; i += 3) {
    arr[i] = (arr[i] * 1.04).clamp(0, 255); // R+
    arr[i + 2] = (arr[i + 2] * 0.96).clamp(0, 255); // B-
  }
  return EffectUtils.fromFloat(arr, src.width, src.height);
}
