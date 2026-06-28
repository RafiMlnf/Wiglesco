class ProcessResult {
  final String outputUrl;
  final String depthMapUrl;
  final String thumbnailUrl;
  final double processingTime;

  const ProcessResult({
    required this.outputUrl,
    required this.depthMapUrl,
    required this.thumbnailUrl,
    required this.processingTime,
  });

  factory ProcessResult.fromJson(Map<String, dynamic> json) {
    return ProcessResult(
      outputUrl: json['output_url'] as String,
      depthMapUrl: json['depth_map_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      processingTime: (json['processing_time'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'output_url': outputUrl,
        'depth_map_url': depthMapUrl,
        'thumbnail_url': thumbnailUrl,
        'processing_time': processingTime,
      };
}
