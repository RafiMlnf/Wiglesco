import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

// Depth Anything V2 Small fixed input size
const int kDepthInputH = 518;
const int kDepthInputW = 518;

// ImageNet normalization: mean and std per channel (RGB order)
const List<double> kMean = [0.485, 0.456, 0.406];
const List<double> kStd  = [0.229, 0.224, 0.225];

/// On-device depth estimation using Depth Anything V2 Small ONNX model.
/// Model asset: assets/models/depth_anything_v2_small.onnx
class OnDeviceDepthService {
  OrtSession? _session;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Load model from Flutter assets.
  /// Call once — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;
    final ort = OnnxRuntime();
    _session = await ort.createSessionFromAsset(
      'assets/models/depth_anything_v2_small.onnx',
    );
    _loaded = true;
  }

  /// Estimate depth from [sourceImage].
  /// Returns a Float32List of length H×W with values in [0, 1].
  Future<Float32List> estimate(img.Image sourceImage) async {
    if (!_loaded || _session == null) {
      throw StateError('Depth model not loaded. Call load() first.');
    }

    // ── Preprocess: resize → NCHW Float32 ────────────────────
    final resized = img.copyResize(
      sourceImage,
      width: kDepthInputW,
      height: kDepthInputH,
      interpolation: img.Interpolation.linear,
    );

    final pixelCount = kDepthInputH * kDepthInputW;
    final tensorData = Float32List(3 * pixelCount);

    for (int c = 0; c < 3; c++) {
      final mean = kMean[c];
      final std  = kStd[c];
      for (int y = 0; y < kDepthInputH; y++) {
        for (int x = 0; x < kDepthInputW; x++) {
          final pixel = resized.getPixel(x, y);
          final raw = c == 0
              ? pixel.r.toDouble()
              : c == 1 ? pixel.g.toDouble() : pixel.b.toDouble();
          tensorData[c * pixelCount + y * kDepthInputW + x] =
              ((raw / 255.0) - mean) / std;
        }
      }
    }

    // ── Run inference ─────────────────────────────────────────
    final inputTensor = await OrtValue.fromList(
      tensorData.toList(),
      [1, 3, kDepthInputH, kDepthInputW],
    );

    final outputs = await _session!.run({'pixel_values': inputTensor});
    await inputTensor.dispose();

    // ── Post-process: flatten + normalize depth to [0, 1] ─────
    final outValue = outputs['predicted_depth'];
    if (outValue == null) throw StateError('No "predicted_depth" in model output');

    // OrtValue.asList() returns nested List for 2D output (1, H, W)
    final rawNested = await outValue.asList();
    final rawFlat = <double>[];
    for (final batch in rawNested) {
      for (final row in batch as List) {
        for (final v in row as List) {
          rawFlat.add((v as num).toDouble());
        }
      }
    }

    return _normalizeDepth(Float32List.fromList(rawFlat));
  }

  Float32List _normalizeDepth(Float32List raw) {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (final v in raw) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    final range = maxVal - minVal;
    if (range < 1e-8) return Float32List(raw.length);

    final out = Float32List(raw.length);
    for (int i = 0; i < raw.length; i++) {
      out[i] = (raw[i] - minVal) / range;
    }
    return out;
  }

  void dispose() {
    _session?.close();
    _session = null;
    _loaded = false;
  }
}
