import 'dart:io';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Encodes a list of img.Image frames into video.
/// Supports: MP4 (via native Hardware-Accelerated MediaCodec/AVFoundation),
/// and GIF (via pure Dart GifEncoder).
class OnDeviceExportService {
  /// Encode frames and return path to output file.
  Future<String> exportFrames({
    required List<img.Image> frames,
    required String format, // 'mp4' | 'gif'
    required int fps,
  }) async {
    final dir = await getTemporaryDirectory();
    final sessionId = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${dir.path}/wiglesco_$sessionId.$format';

    if (frames.isEmpty) {
      throw ArgumentError('Frames list cannot be empty');
    }

    final width = frames[0].width;
    final height = frames[0].height;

    // Ensure width and height are even numbers (required by many video encoders)
    final evenWidth = (width % 2 == 0) ? width : width - 1;
    final evenHeight = (height % 2 == 0) ? height : height - 1;

    if (format.toLowerCase() == 'gif') {
      // ── 1. Pure Dart GIF Encoding (No disk I/O, no FFmpeg) ────────────────
      final encoder = img.GifEncoder();
      
      // Duration per frame is in centiseconds (1/100th of a second)
      final frameDurationCentiseconds = 100 ~/ fps;

      for (final frame in frames) {
        encoder.addFrame(frame, duration: frameDurationCentiseconds);
      }

      final gifBytes = encoder.finish();
      if (gifBytes == null) {
        throw Exception('Failed to encode GIF animation.');
      }

      await File(outputPath).writeAsBytes(gifBytes);
    } else {
      // Calculate bitrate dynamically based on pixel count and FPS
      // Rule of thumb: 0.12 bits per pixel per frame.
      // e.g. 1080p @ 30fps = ~7.4 Mbps.
      // for 3060x4080 @ 9fps = ~13.4 Mbps.
      final calculatedBitrate = (evenWidth * evenHeight * fps * 0.12).round();
      final dynamicBitrate = calculatedBitrate.clamp(2000000, 25000000);

      // ── 2. Hardware-Accelerated MP4 Encoding (No disk I/O, no FFmpeg) ─────
      await FlutterQuickVideoEncoder.setup(
        width: evenWidth,
        height: evenHeight,
        fps: fps,
        videoBitrate: dynamicBitrate,
        profileLevel: ProfileLevel.any,
        audioChannels: 0,
        audioBitrate: 0,
        sampleRate: 0,
        filepath: outputPath,
      );

      try {
        for (final frame in frames) {
          // Resize if width/height are odd to ensure even dimensions
          final processedFrame = (frame.width == evenWidth && frame.height == evenHeight)
              ? frame
              : img.copyResize(frame, width: evenWidth, height: evenHeight);

          // Get raw RGBA bytes directly from RAM
          final rgbaBytes = processedFrame.getBytes(order: img.ChannelOrder.rgba);
          await FlutterQuickVideoEncoder.appendVideoFrame(rgbaBytes);
        }
      } finally {
        await FlutterQuickVideoEncoder.finish();
      }
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
