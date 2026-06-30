import 'dart:io';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../services/on_device/effects/olise.dart';
import '../../services/on_device/effects/nostalgic.dart';

class FilterEditorState {
  final XFile? selectedImage;
  final String selectedFilter; // 'Original' | 'Olise' | 'Nostalgic'
  final String? filteredImagePath;
  final bool isLoading;
  final int filterSeed;
  final double lensDistortion;
  final double imageAspectRatio;
  final String selectedTime; // 'day' | 'golden' | 'night'
  final bool filmBurn;

  const FilterEditorState({
    this.selectedImage,
    this.selectedFilter = 'Original',
    this.filteredImagePath,
    this.isLoading = false,
    this.filterSeed = 0,
    this.lensDistortion = 0.15,
    this.selectedTime = 'day',
    this.imageAspectRatio = 1.3333,
    this.filmBurn = false,
  });

  FilterEditorState copyWith({
    XFile? selectedImage,
    String? selectedFilter,
    String? filteredImagePath,
    bool? isLoading,
    String? selectedTime,
    int? filterSeed,
    double? lensDistortion,
    double? imageAspectRatio,
    bool? filmBurn,
    bool clearImage = false,
    bool clearFilteredPath = false,
  }) {
    return FilterEditorState(
      selectedImage: clearImage ? null : (selectedImage ?? this.selectedImage),
      selectedFilter: selectedFilter ?? this.selectedFilter,
      filteredImagePath: clearFilteredPath
          ? null
          : (filteredImagePath ?? this.filteredImagePath),
      isLoading: isLoading ?? this.isLoading,
      filterSeed: filterSeed ?? this.filterSeed,
      lensDistortion: lensDistortion ?? this.lensDistortion,
      selectedTime: selectedTime ?? this.selectedTime,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      filmBurn: filmBurn ?? this.filmBurn,
    );
  }
}

class FilterEditorNotifier extends StateNotifier<FilterEditorState> {
  FilterEditorNotifier() : super(const FilterEditorState());

  Future<void> setImage(XFile image) async {
    state = state.copyWith(
      selectedImage: image,
      selectedFilter: 'Original',
      clearFilteredPath: true,
      filterSeed: 0,
      isLoading: true,
      lensDistortion: 0.15,
    );

    try {
      final bytes = await File(image.path).readAsBytes();
      final srcImg = img.decodeImage(bytes);
      if (srcImg != null) {
        final double ratio = srcImg.width / srcImg.height;
        state = state.copyWith(
          imageAspectRatio: ratio,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setLensDistortion(double val) {
    state = state.copyWith(lensDistortion: val);
    if (state.selectedFilter != 'Original' && state.selectedImage != null) {
      _applyFilter();
    }
  }

  void regenerate() {
    if (state.selectedImage != null && state.selectedFilter != 'Original') {
      state = state.copyWith(
        filterSeed: DateTime.now().millisecondsSinceEpoch,
      );
      _applyFilter();
    }
  }

  Future<void> setFilter(String filter) async {
    if (state.selectedImage == null) return;

    if (filter == 'Original') {
      state = state.copyWith(
        selectedFilter: 'Original',
        clearFilteredPath: true,
        filterSeed: 0,
        isLoading: false,
      );
      return;
    }

    final int newSeed = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(
      selectedFilter: filter,
      filterSeed: newSeed,
    );
    _applyFilter();
  }

  Future<void> _applyFilter() async {
    if (state.selectedImage == null || state.selectedFilter == 'Original') return;

    state = state.copyWith(isLoading: true);

    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/filter_preview_$ts.jpg';

      final args = _FilterArgs(
        inputPath: state.selectedImage!.path,
        outputPath: outputPath,
        filterName: state.selectedFilter,
        seed: state.filterSeed,
        distortion: state.lensDistortion,
        selectedTime: state.selectedTime,
        filmBurn: state.filmBurn,
      );

      await Isolate.run(() => _applyFilterIsolate(args));

      state = state.copyWith(
        filteredImagePath: outputPath,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setTime(String time) {
    state = state.copyWith(
      selectedTime: time,
      filterSeed: DateTime.now().millisecondsSinceEpoch,
    );
    if (state.selectedFilter == 'Nostalgic' && state.selectedImage != null) {
      _applyFilter();
    }
  }

  void setFilmBurn(bool value) {
    state = state.copyWith(
      filmBurn: value,
      filterSeed: DateTime.now().millisecondsSinceEpoch,
    );
    if (state.selectedFilter == 'Nostalgic' && state.selectedImage != null) {
      _applyFilter();
    }
  }

  void clear() {
    state = const FilterEditorState();
  }
}

// ── Isolate Worker ────────────────────────────────────────────────────────────

class _FilterArgs {
  final String inputPath;
  final String outputPath;
  final String filterName;
  final int seed;
  final double distortion;
  final String selectedTime;
  final bool filmBurn;

  _FilterArgs({
    required this.inputPath,
    required this.outputPath,
    required this.filterName,
    required this.seed,
    required this.distortion,
    required this.selectedTime,
    this.filmBurn = false,
  });
}

void _applyFilterIsolate(_FilterArgs args) {
  final bytes = File(args.inputPath).readAsBytesSync();
  img.Image? srcImg = img.decodeImage(bytes);
  if (srcImg == null) return;

  // Downscale to max 1080px on longest side
  const int maxDimension = 1080;
  if (srcImg.width > maxDimension || srcImg.height > maxDimension) {
    final double ratio = srcImg.width / srcImg.height;
    final int tw, th;
    if (srcImg.width > srcImg.height) {
      tw = maxDimension;
      th = (maxDimension / ratio).round();
    } else {
      th = maxDimension;
      tw = (maxDimension * ratio).round();
    }
    srcImg = img.copyResize(srcImg,
        width: tw, height: th, interpolation: img.Interpolation.linear);
  }

  final img.Image result;
  switch (args.filterName.toLowerCase()) {
    case 'olise':
      result = applyOlise(srcImg, args.seed, args.distortion);
    case 'nostalgic':
      result = applyNostalgicEffect(srcImg, args.seed, args.selectedTime,
          filmBurn: args.filmBurn);
    default:
      result = srcImg;
  }

  final outBytes = img.encodeJpg(result, quality: 90);
  File(args.outputPath).writeAsBytesSync(outBytes);
}

final filterEditorProvider =
    StateNotifierProvider<FilterEditorNotifier, FilterEditorState>(
  (ref) => FilterEditorNotifier(),
);
