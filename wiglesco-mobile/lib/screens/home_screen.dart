import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import '../providers/editor_provider.dart';
import '../providers/history_provider.dart';
import 'filter_editor/filter_editor_provider.dart';
import '../models/history_item.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppColors.gradientStart,
                              AppColors.gradientEnd
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Wiglesco',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '3D Parallax & Wigglegram Creator',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Premium Gold Crown Icon/Button
                    IconButton(
                      icon: const CustomCrownIcon(
                        size: 26,
                        color: Colors.amber,
                      ),
                      onPressed: () => context.push('/paywall'),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
              ),
            ),

            // ── Pick Buttons ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: Column(
                  children: [
                     _PickButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Pick from Gallery',
                      subtitle: 'JPEG · PNG · WebP · HEIC',
                      hasShimmer: true,
                      onTap: () =>
                          _pickImage(context, ref, ImageSource.gallery),
                    ),
                    const SizedBox(height: 12),
                    _PickButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      subtitle: 'Use your camera',
                      hasShimmer: false,
                      onTap: () =>
                          _pickImage(context, ref, ImageSource.camera),
                    ),
                    const SizedBox(height: 12),
                    _PickButton(
                      icon: Icons.color_lens_rounded,
                      label: 'Filter Editor',
                      subtitle: 'Olise · Nostalgic · Dreamy',
                      hasShimmer: false,
                      onTap: () => _openFilterEditor(context),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
              ),
            ),



            // ── Recent History ───────────────────────────────────────────────
            if (history.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Recent',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${history.length}',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: history.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final item = history[i];
                      return GestureDetector(
                        onTap: () => context.push('/result', extra: item),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildThumbnail(item),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    item.filename.replaceAll(
                                        RegExp(r'\.[^/.]+$'), ''),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: (200 + i * 50).ms),
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Empty State ──────────────────────────────────────────────────
            if (history.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_motion_rounded,
                          size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No renders yet',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('Pick a photo to get started',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ).animate().fadeIn(delay: 300.ms),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(HistoryItem item) {
    final path = item.thumbnailPath;
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _thumbFallback());
      }
    }
    return _thumbFallback();
  }

  Widget _thumbFallback() => Container(
        color: AppColors.surfaceElevated,
        child: const Icon(Icons.movie_creation_outlined,
            color: AppColors.textMuted, size: 24),
      );

  Future<void> _pickImage(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;
    ref.read(editorProvider.notifier).setImage(picked);
    if (context.mounted) context.push('/editor');
  }

  void _openFilterEditor(BuildContext context) {
    context.push('/filter-editor');
  }
}

// ── Pick Button ───────────────────────────────────────────────────────────────

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool hasShimmer;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.hasShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.zero;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 80,
        child: Stack(
          children: [
            // 1. Base Dark & Neutral Card
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: hasShimmer ? Colors.transparent : AppColors.border,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

            // 2. Shimmering Glow Outer Stroke (Top Layer)
            if (hasShimmer)
              Positioned.fill(
                child: IgnorePointer(
                  child: Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.0),
                    highlightColor: Colors.white.withOpacity(0.4),
                    period: const Duration(milliseconds: 2500),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomCrownIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CustomCrownIcon({
    super.key,
    this.size = 28.0,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/crown.png',
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}



