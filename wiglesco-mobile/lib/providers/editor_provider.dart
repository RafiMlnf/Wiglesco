import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/on_device/pipeline.dart';
import '../services/server/server_pipeline_service.dart';
import 'settings_provider.dart';

// ── Editor State ─────────────────────────────────────────────────────────────

class EditorState {
  final XFile? selectedImage;
  final int numFrames;
  final double parallaxStrength;
  final String effectStyle;
  final String exportFormat;
  final int fps;
  final bool isLoading;
  final String currentStep;
  final int currentStepIndex;
  final String? error;
  final OnDeviceResult? result;

  const EditorState({
    this.selectedImage,
    this.numFrames = 6,
    this.parallaxStrength = 0.6,
    this.effectStyle = 'nishika',
    this.exportFormat = 'mp4',
    this.fps = 15,
    this.isLoading = false,
    this.currentStep = 'Ready',
    this.currentStepIndex = 0,
    this.error,
    this.result,
  });

  EditorState copyWith({
    XFile? selectedImage,
    int? numFrames,
    double? parallaxStrength,
    String? effectStyle,
    String? exportFormat,
    int? fps,
    bool? isLoading,
    String? currentStep,
    int? currentStepIndex,
    String? error,
    OnDeviceResult? result,
    bool clearImage = false,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return EditorState(
      selectedImage: clearImage ? null : (selectedImage ?? this.selectedImage),
      numFrames: numFrames ?? this.numFrames,
      parallaxStrength: parallaxStrength ?? this.parallaxStrength,
      effectStyle: effectStyle ?? this.effectStyle,
      exportFormat: exportFormat ?? this.exportFormat,
      fps: fps ?? this.fps,
      isLoading: isLoading ?? this.isLoading,
      currentStep: currentStep ?? this.currentStep,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

// ── Editor Notifier ───────────────────────────────────────────────────────────

class EditorNotifier extends StateNotifier<EditorState> {
  final Ref _ref;

  EditorNotifier(this._ref) : super(const EditorState()) {
    // Initialize depth model in background at startup
    _pipeline.initialize().catchError((e) {
      // Non-fatal — will retry on first render
    });
  }

  final OnDevicePipeline _pipeline = OnDevicePipeline();
  final ServerPipelineService _serverPipeline = ServerPipelineService();

  void setImage(XFile image) {
    state = state.copyWith(
      selectedImage: image,
      clearResult: true,
      clearError: true,
    );
  }

  void clearImage() {
    state = state.copyWith(
        clearImage: true, clearResult: true, clearError: true);
  }

  void setFrames(int frames) => state = state.copyWith(numFrames: frames);
  void setStrength(double s) => state = state.copyWith(parallaxStrength: s);
  void setStyle(String s) => state = state.copyWith(effectStyle: s);
  void setFormat(String f) => state = state.copyWith(exportFormat: f);
  void setFps(int fps) => state = state.copyWith(fps: fps);

  Future<void> render() async {
    if (state.selectedImage == null) return;
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearResult: true,
      currentStep: 'Starting...',
      currentStepIndex: 0,
    );

    try {
      final settings = _ref.read(settingsProvider);
      final OnDeviceResult result;

      if (settings.useServerMode) {
        result = await _serverPipeline.run(
          serverUrl: settings.serverUrl,
          imagePath: state.selectedImage!.path,
          numFrames: state.numFrames,
          parallaxStrength: state.parallaxStrength,
          effectStyle: state.effectStyle,
          exportFormat: state.exportFormat,
          fps: state.fps,
          onProgress: (step, index, total) {
            if (mounted) {
              state = state.copyWith(
                currentStep: step,
                currentStepIndex: index,
              );
            }
          },
        );
      } else {
        result = await _pipeline.run(
          imagePath: state.selectedImage!.path,
          numFrames: state.numFrames,
          parallaxStrength: state.parallaxStrength,
          effectStyle: state.effectStyle,
          exportFormat: state.exportFormat,
          fps: state.fps,
          onProgress: (step, index, total) {
            if (mounted) {
              state = state.copyWith(
                currentStep: step,
                currentStepIndex: index,
              );
            }
          },
        );
      }

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          result: result,
          currentStep: 'Done!',
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          clearResult: true,
          error: e.toString().replaceFirst('Exception: ', ''),
          currentStep: 'Ready',
        );
      }
    }
  }

  @override
  void dispose() {
    _pipeline.dispose();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>(
  (ref) => EditorNotifier(ref),
);
