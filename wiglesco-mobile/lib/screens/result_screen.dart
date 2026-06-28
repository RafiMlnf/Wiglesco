import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../core/theme.dart';
import '../models/history_item.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final HistoryItem item;
  const ResultScreen({super.key, required this.item});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VideoPlayerController? _videoController;
  bool _isMuted = false;
  bool _isSaving = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // For local results, show only the output tab (no original/depth stored)
    _tabController = TabController(
      length: widget.item.isLocal ? 1 : 3,
      vsync: this,
    );
    _initVideo();
  }

  Future<void> _initVideo() async {
    final item = widget.item;
    final String path = item.outputPath;
    if (item.format.toLowerCase() == 'gif' || path.toLowerCase().endsWith('.gif')) {
      return; // Natively rendered as animated image, no video player controller needed
    }

    // Local file
    _videoController = VideoPlayerController.file(File(path));
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
    } catch (e) {
      // Fallback
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    final wasPlaying = _videoController?.value.isPlaying ?? false;
    if (wasPlaying) {
      await _videoController?.pause();
    }

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) await Gal.requestAccess(toAlbum: false);

      final path = widget.item.outputPath;
      final format = widget.item.format;

      if (format == 'mp4') {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Saved to gallery!', Icons.check_circle_rounded, AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Save failed: $e', Icons.error_outline, AppColors.error),
        );
      }
    } finally {
      if (wasPlaying && mounted) {
        _videoController?.play();
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await Share.shareXFiles(
        [XFile(widget.item.outputPath)],
        text: 'Made with Wiglesco — 3D Parallax Creator',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Share failed: $e', Icons.error_outline, AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  SnackBar _snackBar(String msg, IconData icon, Color color) => SnackBar(
        content: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        duration: const Duration(seconds: 3),
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Result'),
        actions: [
          if (_videoController?.value.isInitialized == true)
            IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() => _isMuted = !_isMuted);
                _videoController?.setVolume(_isMuted ? 0 : 1);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Video / Image Preview ────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  color: AppColors.surface,
                  child: _buildPreview(),
                ),
              ),
            ),
          ),

          // ── Stats Card ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                      label: 'Time',
                      value: '${item.processingTime.toStringAsFixed(1)}s'),
                  _divider(),
                  _StatItem(label: 'Format', value: item.format.toUpperCase()),
                  _divider(),
                  _StatItem(label: 'Style', value: _shortStyle(item.style)),
                  if (item.width > 0) ...[
                    _divider(),
                    _StatItem(label: 'Size', value: '${item.width}×${item.height}'),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
          ),

          // ── Action Buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.save_alt_rounded,
                    label: _isSaving ? 'Saving...' : 'Save',
                    onTap: _isSaving ? null : _saveToGallery,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_rounded,
                    label: _isSharing ? 'Sharing...' : 'Share',
                    onTap: _isSharing ? null : _share,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.add_photo_alternate_rounded,
                    label: 'New',
                    onTap: () => context.go('/'),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final item = widget.item;
    final path = item.outputPath;
    if (item.format.toLowerCase() == 'gif' || path.toLowerCase().endsWith('.gif')) {
      if (File(path).existsSync()) {
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      }
    }

    if (_videoController?.value.isInitialized == true) {
      return GestureDetector(
        onTap: () {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
          setState(() {});
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
            if (!_videoController!.value.isPlaying)
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
          ],
        ),
      );
    }

    // Fallback: show thumbnail or loading
    final thumbnailPath = widget.item.thumbnailPath;
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      return Image.file(File(thumbnailPath), fit: BoxFit.contain);
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: AppColors.border);

  String _shortStyle(String s) =>
      s == 'retro_warm' ? 'Retro' : s[0].toUpperCase() + s.substring(1);
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: primary && onTap != null
                ? const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  )
                : null,
            color: primary
                ? (onTap == null ? Colors.white24 : null)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
                color: primary ? Colors.transparent : AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: onTap != null
                      ? (primary ? Colors.black : Colors.white)
                      : (primary ? Colors.white38 : AppColors.textMuted),
                  size: 20),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    color: onTap != null
                        ? (primary ? Colors.black : Colors.white)
                        : (primary ? Colors.white38 : AppColors.textMuted),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      );
}
