import 'dart:io';

import 'package:image/image.dart' as img;

import 'depth_service.dart';
import 'export_service.dart';
import 'style_service.dart';
import 'synthesis_service.dart';

/// Pipeline step labels — same as web version
const List<String> kPipelineSteps = [
  'Preprocessing image',
  'Estimating depth map',
  'Synthesizing parallax frames',
  'Applying style',
  'Encoding video',
];

typedef ProgressCallback = void Function(String step, int stepIndex, int totalSteps);

/// Result of the on-device pipeline
class OnDeviceResult {
  final String outputPath;      // local file path (mp4/gif)
  final String thumbnailPath;   // local JPEG path
  final double processingTime;  // seconds
  final int width;
  final int height;

  const OnDeviceResult({
    required this.outputPath,
    required this.thumbnailPath,
    required this.processingTime,
    required this.width,
    required this.height,
  });
}

/// Orchestrates the full on-device AI pipeline:
///   Input Photo → Preprocess → Depth → Synthesis → Style → Export
class OnDevicePipeline {
  final OnDeviceDepthService _depth = OnDeviceDepthService();
  final OnDeviceSynthesisService _synthesis = OnDeviceSynthesisService();
  final OnDeviceStyleService _style = OnDeviceStyleService();
  final OnDeviceExportService _export = OnDeviceExportService();

  bool _loaded = false;

  /// Load TFLite model. Call once at app startup.
  Future<void> initialize() async {
    if (_loaded) return;
    await _depth.load();
    _loaded = true;
  }

  bool get isReady => _loaded;

  /// Run complete pipeline.
  Future<OnDeviceResult> run({
    required String imagePath,
    required int numFrames,
    required double parallaxStrength,
    required String effectStyle,
    required String exportFormat,
    required int fps,
    ProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // ── Step 1: Preprocess ────────────────────────────────────
    onProgress?.call(kPipelineSteps[0], 0, kPipelineSteps.length);

    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? srcImage = img.decodeImage(imageBytes);
    if (srcImage == null) throw Exception('Cannot decode image');



    // ── Step 2: Depth Estimation ──────────────────────────────
    onProgress?.call(kPipelineSteps[1], 1, kPipelineSteps.length);

    if (!_loaded) await initialize();
    final depthMap = await _depth.estimate(srcImage);

    // ── Step 3: Parallax Synthesis ────────────────────────────
    onProgress?.call(kPipelineSteps[2], 2, kPipelineSteps.length);

    List<img.Image> frames = await _synthesis.generateFrames(
      source: srcImage,
      depthMap: depthMap,
      numFrames: numFrames,
      parallaxStrength: parallaxStrength,
    );

    // Convert to ping-pong bounce loop: 1 2 3 4 -> 3 2
    if (frames.length > 2) {
      final pingPong = <img.Image>[...frames];
      for (int i = frames.length - 2; i >= 1; i--) {
        pingPong.add(frames[i]);
      }
      frames = pingPong;
    }

    // ── Step 4: Style / Enhancement ───────────────────────────
    onProgress?.call(kPipelineSteps[3], 3, kPipelineSteps.length);
    frames = _style.applyStyle(frames, effectStyle);

    // ── Step 5: Export ────────────────────────────────────────
    onProgress?.call(kPipelineSteps[4], 4, kPipelineSteps.length);

    final outputPath = await _export.exportFrames(
      frames: frames,
      format: exportFormat,
      fps: fps,
    );

    final thumbnailPath = await _export.generateThumbnail(frames);

    stopwatch.stop();

    return OnDeviceResult(
      outputPath: outputPath,
      thumbnailPath: thumbnailPath,
      processingTime: stopwatch.elapsed.inMilliseconds / 1000.0,
      width: srcImage.width,
      height: srcImage.height,
    );
  }

  void dispose() {
    _depth.dispose();
    _loaded = false;
  }
}
