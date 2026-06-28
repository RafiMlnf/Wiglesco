/// Application-wide constants for Wiglesco Mobile (Serverless / On-Device mode).
/// Backend URL config has been removed — all processing runs on-device.

// ── Model Assets ─────────────────────────────────────────────────────────────

/// Asset path to the ONNX depth estimation model
const String kDepthModelAssetPath =
    'assets/models/depth_anything_v2_small.onnx';

// ── Style Presets ─────────────────────────────────────────────────────────────

const List<String> kStyleKeys = [
  'normal',
  'nishika',
  'analog',
  'retro_warm',
  'cinematic',
  'glitch',
  'cyberpunk',
];

const Map<String, String> kStyleLabels = {
  'normal':     'Normal',
  'nishika':    'Nishika N8000',
  'analog':     'Analog Film',
  'retro_warm': 'Retro Warm',
  'cinematic':  'Cinematic',
  'glitch':     'Glitch',
  'cyberpunk':  'Cyberpunk',
};

const Map<String, String> kStyleEmojis = {
  'normal':     '⚪',
  'nishika':    '📷',
  'analog':     '🎞️',
  'retro_warm': '🌅',
  'cinematic':  '🎬',
  'glitch':     '⚡',
  'cyberpunk':  '🌆',
};

// ── Parameter Options ─────────────────────────────────────────────────────────

const List<int>    kFrameOptions  = [3, 4, 6, 8];
const List<String> kFormatOptions = ['mp4', 'gif'];
const List<int>    kFpsOptions    = [10, 15, 24];
