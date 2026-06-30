import 'package:image/image.dart' as img;
import 'effects/nishika.dart';
import 'effects/analog.dart';
import 'effects/retro_warm.dart';
import 'effects/cinematic.dart';
import 'effects/glitch.dart';
import 'effects/cyberpunk.dart';

/// Port of Python EnhancementService — color grading effects router.
class OnDeviceStyleService {
  /// Apply style preset to all frames.
  List<img.Image> applyStyle(List<img.Image> frames, String style) {
    return frames.map((f) => _applyStyle(f, style)).toList();
  }

  /// Apply style to a single frame.
  img.Image applyStyle1(img.Image frame, String style) =>
      _applyStyle(frame, style);

  img.Image _applyStyle(img.Image image, String style) {
    switch (style.toLowerCase()) {
      case 'nishika':
        return applyNishika(image);
      case 'analog':
        return applyAnalog(image);
      case 'retro_warm':
        return applyRetroWarm(image);
      case 'cinematic':
        return applyCinematic(image);
      case 'glitch':
        return applyGlitch(image);
      case 'cyberpunk':
        return applyCyberpunk(image);
      default:
        return image; // 'normal'
    }
  }
}
