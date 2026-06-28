import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Encodes a list of img.Image frames into video using FFmpeg Kit.
/// Supports: MP4, GIF.
class OnDeviceExportService {
  /// Encode frames and return path to output file.
  Future<String> exportFrames({
    required List<img.Image> frames,
    required String format, // 'mp4' | 'gif'
    required int fps,
  }) async {
    final dir = await getTemporaryDirectory();
    final sessionId = DateTime.now().millisecondsSinceEpoch;
    final framesDir = Directory('${dir.path}/frames_$sessionId');
    await framesDir.create();

    // ── 1. Write frames as PNG to temp dir ───────────────────
    for (int i = 0; i < frames.length; i++) {
      final pngBytes = img.encodePng(frames[i]);
      final framePath = '${framesDir.path}/frame_${i.toString().padLeft(4, '0')}.png';
      await File(framePath).writeAsBytes(pngBytes);
    }

    final outputPath = '${dir.path}/wiglesco_$sessionId.$format';
    final inputPattern = '${framesDir.path}/frame_%04d.png';

    // ── 2. Build FFmpeg command ───────────────────────────────
    final String cmd;
    switch (format) {
      case 'gif':
        // High-quality GIF with palette
        cmd = '-y -framerate $fps -i "$inputPattern" '
            '-vf "fps=$fps,scale=${frames[0].width}:-1:flags=lanczos,'
            'split[a][b];[a]palettegen[p];[b][p]paletteuse" '
            '"$outputPath"';
        break;

      case 'mp4':
      default:
        // H.264 MP4 — compatible with most Android players & social media
        // scale=trunc(iw/2)*2:trunc(ih/2)*2 ensures width and height are divisible by 2 (required by yuv420p)
        cmd = '-y -framerate $fps -i "$inputPattern" '
            '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" '
            '-c:v libx264 -pix_fmt yuv420p -preset superfast -crf 17 '
            '"$outputPath"';
        break;
    }

    // ── 3. Execute FFmpeg ─────────────────────────────────────
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    // Cleanup frame files
    await framesDir.delete(recursive: true);

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      print('=== FFmpeg kit execution failed! ===');
      print(logs);
      print('=====================================');
      throw Exception('FFmpeg failed. Check terminal logs for details.');
    }

    return outputPath;
  }

  /// Generate a thumbnail JPEG from the middle frame.
  Future<String> generateThumbnail(List<img.Image> frames) async {
    final dir = await getTemporaryDirectory();
    final mid = frames[frames.length ~/ 2];
    final thumbPath = '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final jpgBytes = img.encodeJpg(mid, quality: 85);
    await File(thumbPath).writeAsBytes(jpgBytes);
    return thumbPath;
  }
}
