import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import '../providers/editor_provider.dart';
import '../providers/history_provider.dart';
import '../providers/premium_provider.dart';
import '../models/history_item.dart';
import '../widgets/common/loading_overlay.dart';
import '../widgets/editor/control_panel.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate to result when processing completes
    ref.listen<EditorState>(editorProvider, (prev, next) {
      if (prev?.isLoading == true && !next.isLoading && next.result != null) {
        // Save to history
        final item = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filename: next.selectedImage?.name ?? 'photo.jpg',
          outputPath: next.result!.outputPath,
          thumbnailPath: next.result!.thumbnailPath,
          processingTime: next.result!.processingTime,
          style: next.effectStyle,
          format: next.exportFormat,
          createdAt: DateTime.now(),
          isLocal: true,
          width: next.result!.width,
          height: next.result!.height,
        );
        ref.read(historyProvider.notifier).addItem(item);
        context.push('/result', extra: item);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editor'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final hasError = ref.watch(editorProvider.select((s) => s.error != null));
              if (!hasError) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 20),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Image Preview ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (context, ref, child) {
                    final selectedImage = ref.watch(editorProvider.select((s) => s.selectedImage));
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: selectedImage != null
                              ? Image.file(
                                  File(selectedImage.path),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: AppColors.surface,
                                  child: const Icon(Icons.image_outlined,
                                      size: 48, color: AppColors.textMuted),
                                ),
                        ),
                      ).animate(key: ValueKey(selectedImage?.path)).fadeIn(duration: 300.ms),
                    );
                  },
                ),
              ),

              // ── Error Banner ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (context, ref, child) {
                    final error = ref.watch(editorProvider.select((s) => s.error));
                    if (error == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                error,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(key: ValueKey(error)).shakeX(),
                    );
                  },
                ),
              ),

              // ── Controls ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (context, ref, child) {
                    final state = ref.watch(editorProvider);
                    final notifier = ref.read(editorProvider.notifier);
                    return ControlPanel(state: state, notifier: notifier);
                  },
                ),
              ),

              // Bottom spacing to prevent floating button overlaying content
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),

          // ── Floating Render Button ──────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Consumer(
              builder: (context, ref, child) {
                final enabled = ref.watch(editorProvider.select((s) => s.selectedImage != null && !s.isLoading));
                final isLoading = ref.watch(editorProvider.select((s) => s.isLoading));
                return _RenderButton(
                  enabled: enabled,
                  isLoading: isLoading,
                  onTap: () {
                    final premium = ref.read(premiumProvider);
                    final history = ref.read(historyProvider);
                    
                    // Gate: if not premium and history is >= 3 items, show paywall!
                    if (!premium.isPremium && history.length >= 3) {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: AppColors.surfaceElevated,
                          title: const Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                              SizedBox(width: 10),
                              Text('Free Limit Reached', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          content: const Text(
                            'You have reached the daily limit of 3 free 3D parallax renders. Upgrade to Premium for unlimited generations and super fast cloud processing!',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Maybe Later', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                context.push('/paywall');
                              },
                              child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ref.read(editorProvider.notifier).render();
                    }
                  },
                );
              },
            ),
          ),

          // ── Loading Overlay ─────────────────────────────────────────────
          Consumer(
            builder: (context, ref, child) {
              final isLoading = ref.watch(editorProvider.select((s) => s.isLoading));
              if (!isLoading) return const SizedBox.shrink();
              final currentStep = ref.watch(editorProvider.select((s) => s.currentStep));
              final currentStepIndex = ref.watch(editorProvider.select((s) => s.currentStepIndex));
              return LoadingOverlay(
                currentStep: currentStep,
                currentStepIndex: currentStepIndex,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Render Button ─────────────────────────────────────────────────────────────

class _RenderButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _RenderButton({
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(30);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              // 1. Glassmorphism Button Body (with BackdropFilter blur) - Bottom Layer
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: -2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLoading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isLoading ? 'PROCESSING...' : 'RENDER PARALLAX',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Shimmering Glow Outer Stroke (Only when enabled and not loading) - Top Layer
              if (enabled && !isLoading)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(0.0),
                      highlightColor: Colors.white.withOpacity(0.8),
                      period: const Duration(milliseconds: 2000),
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
      ),
    );
  }
}
