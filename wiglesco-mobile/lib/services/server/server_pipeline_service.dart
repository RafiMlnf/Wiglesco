import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../on_device/pipeline.dart';

class ServerPipelineService {
  final Dio _dio = Dio();

  Future<OnDeviceResult> run({
    required String serverUrl,
    required String imagePath,
    required int numFrames,
    required double parallaxStrength,
    required String effectStyle,
    required String exportFormat,
    required int fps,
    void Function(String step, int index, int total)? onProgress,
  }) async {
    onProgress?.call('UPLOADING TO SERVER...', 0, 4);

    // 1. Prepare FormData
    final file = await MultipartFile.fromFile(imagePath, filename: 'input.jpg');
    final formData = FormData.fromMap({
      'file': file,
      'num_frames': numFrames,
      'parallax_strength': parallaxStrength,
      'effect_style': effectStyle,
      'export_format': exportFormat,
      'fps': fps,
    });

    onProgress?.call('PROCESSING ON SERVER...', 1, 4);

    // 2. Call process direct endpoint
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final response = await _dio.post(
      '$cleanUrl/api/v1/process/direct',
      data: formData,
    );

    if (response.statusCode != 200) {
      throw Exception('Server returned status code ${response.statusCode}');
    }

    final data = response.data;
    if (data['status'] != 'success') {
      throw Exception('Server processing failed: ${data['detail'] ?? 'Unknown error'}');
    }

    final String outputUrl = data['output_url'];
    final String thumbnailUrl = data['thumbnail_url'];
    final double processingTime = (data['processing_time'] as num).toDouble();

    onProgress?.call('DOWNLOADING RESULT...', 2, 4);

    // 3. Download output and thumbnail to temp files
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final localOutputPath = '${tempDir.path}/server_out_$timestamp.$exportFormat';
    final localThumbnailPath = '${tempDir.path}/server_thumb_$timestamp.jpg';

    // Replace localhost/127.0.0.1 in URL with serverUrl host if running on emulator/device
    final finalOutputUrl = _resolveUrl(outputUrl, cleanUrl);
    final finalThumbnailUrl = _resolveUrl(thumbnailUrl, cleanUrl);

    await _dio.download(finalOutputUrl, localOutputPath);
    onProgress?.call('DOWNLOADING THUMBNAIL...', 3, 4);
    await _dio.download(finalThumbnailUrl, localThumbnailPath);

    onProgress?.call('DONE!', 4, 4);

    return OnDeviceResult(
      outputPath: localOutputPath,
      thumbnailPath: localThumbnailPath,
      processingTime: processingTime,
      width: 0,
      height: 0,
    );
  }

  String _resolveUrl(String url, String baseServerUrl) {
    if (url.startsWith('http://localhost:8000')) {
      return url.replaceFirst('http://localhost:8000', baseServerUrl);
    }
    if (url.startsWith('http://127.0.0.1:8000')) {
      return url.replaceFirst('http://127.0.0.1:8000', baseServerUrl);
    }
    return url;
  }
}
