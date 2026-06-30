import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../core/theme.dart';
import 'filter_editor_provider.dart';

class FilterEditorScreen extends ConsumerWidget {
  const FilterEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterEditorProvider);
    final selectedImage = state.selectedImage;

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;
      ref.read(filterEditorProvider.notifier).setImage(picked);
    }

    Future<void> saveToGallery() async {
      final path = state.filteredImagePath ?? selectedImage?.path;
      if (path == null) return;

      // Show blocking loading dialog during save
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryLight,
          ),
        ),
      );

      try {
        final hasAccess = await Gal.hasAccess(toAlbum: false);
        if (!hasAccess) await Gal.requestAccess(toAlbum: false);

        await Gal.putImage(path);

        HapticFeedback.mediumImpact();

        if (context.mounted) {
          // Dismiss loading dialog
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Saved to gallery!'),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );

          ref.read(filterEditorProvider.notifier).clear();
          context.pop(); // Navigate back home
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Save failed: $e'),
                ],
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            ref.read(filterEditorProvider.notifier).clear();
            context.pop();
          },
        ),
        title: const Text('Filter Editor'),
        actions: [
          if (selectedImage != null && !state.isLoading)
            TextButton(
              onPressed: saveToGallery,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image Preview or Placeholder ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: AspectRatio(
                  // Use actual image ratio when loaded, 4:3 for placeholder
                  aspectRatio: selectedImage != null
                      ? state.imageAspectRatio
                      : 4 / 3,
                  child: GestureDetector(
                    onTap: state.isLoading ? null : pickImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (selectedImage != null)
                          SizedBox.expand(
                            child: state.filteredImagePath != null
                                ? Image.file(
                                    File(state.filteredImagePath!),
                                    fit: BoxFit.contain,
                                    key: ValueKey(state.filteredImagePath),
                                  )
                                : Image.file(
                                    File(selectedImage.path),
                                    fit: BoxFit.contain,
                                    key: ValueKey(selectedImage.path),
                                  ),
                          )
                        else
                          SizedBox.expand(
                            child: Container(
                              color: AppColors.surface,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'PILIH GAMBAR',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (state.isLoading)
                          SizedBox.expand(
                            child: Container(
                              color: Colors.black.withOpacity(0.5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Nostalgic: Manual Time of Day Selector ──
            if (state.selectedFilter == 'Nostalgic' && selectedImage != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'TIME OF DAY',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _TimeButton(
                          icon: Icons.wb_sunny_outlined,
                          label: 'DAY',
                          value: 'day',
                          selected: state.selectedTime == 'day',
                          onTap: () => ref
                              .read(filterEditorProvider.notifier)
                              .setTime('day'),
                        ),
                        const SizedBox(width: 8),
                        _TimeButton(
                          icon: Icons.wb_twilight_outlined,
                          label: 'GOLDEN',
                          value: 'golden',
                          selected: state.selectedTime == 'golden',
                          onTap: () => ref
                              .read(filterEditorProvider.notifier)
                              .setTime('golden'),
                        ),
                        const SizedBox(width: 8),
                        _TimeButton(
                          icon: Icons.nights_stay_outlined,
                          label: 'NIGHT',
                          value: 'night',
                          selected: state.selectedTime == 'night',
                          onTap: () => ref
                              .read(filterEditorProvider.notifier)
                              .setTime('night'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Film Burn Toggle ──
                    GestureDetector(
                      onTap: () => ref
                          .read(filterEditorProvider.notifier)
                          .setFilmBurn(!state.filmBurn),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: state.filmBurn
                              ? const Color(0xFFFF6B2C).withOpacity(0.15)
                              : AppColors.surface,
                          border: Border.all(
                            color: state.filmBurn
                                ? const Color(0xFFFF6B2C)
                                : AppColors.border,
                            width: state.filmBurn ? 1.5 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_outlined,
                              size: 16,
                              color: state.filmBurn
                                  ? const Color(0xFFFF6B2C)
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'FILM BURN',
                              style: TextStyle(
                                color: state.filmBurn
                                    ? const Color(0xFFFF6B2C)
                                    : AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.filmBurn ? 'ON' : 'OFF',
                              style: TextStyle(
                                color: state.filmBurn
                                    ? const Color(0xFFFF6B2C)
                                    : AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Lens Curvature Slider Control ──
            if (state.selectedFilter == 'Olise' && selectedImage != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Lens Curvature',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Distortion Intensity',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(state.lensDistortion * 100).round()}%',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Slider(
                        value: state.lensDistortion,
                        min: 0.0,
                        max: 0.4,
                        onChanged: state.isLoading
                            ? null
                            : ref
                                .read(filterEditorProvider.notifier)
                                .setLensDistortion,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Choose Filter Style',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                if (state.selectedFilter != 'Original' && !state.isLoading) ...[
                  TextButton.icon(
                    onPressed: () {
                      ref.read(filterEditorProvider.notifier).regenerate();
                    },
                    icon: const Icon(Icons.refresh_rounded,
                        size: 14, color: AppColors.primaryLight),
                    label: const Text(
                      'RE-GENERATE',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(filterEditorProvider.notifier)
                          .setFilter('Original');
                    },
                    child: const Text(
                      'RESET',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),

            // ── Filter Options Card Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: ['Olise', 'Nostalgic', 'Dreamy'].map((f) {
                    final active = state.selectedFilter == f;
                    return Expanded(
                      child: GestureDetector(
                        onTap: state.isLoading
                            ? null
                            : () {
                                ref
                                    .read(filterEditorProvider.notifier)
                                    .setFilter(f);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: active
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.gradientStart,
                                      AppColors.gradientEnd
                                    ],
                                  )
                                : null,
                            color: active ? null : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              f.toUpperCase(),
                              style: TextStyle(
                                color: active
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _TimeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryLight.withOpacity(0.15)
                : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.border,
              width: selected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primaryLight : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? AppColors.primaryLight : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
