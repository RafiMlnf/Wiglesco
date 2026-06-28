import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/history_item.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('History'),
            const SizedBox(width: 8),
            if (history.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
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
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
        ],
      ),
      body: history.isEmpty
          ? _EmptyState()
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: history.length,
              itemBuilder: (context, i) {
                final item = history[i];
                return _HistoryCard(
                  item: item,
                  index: i,
                  onTap: () => context.push('/result', extra: item),
                  onDelete: () =>
                      ref.read(historyProvider.notifier).removeItem(item.id),
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Clear History',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('All render history will be deleted.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            child: const Text('Delete All',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildThumbnail(item),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.filename.replaceAll(RegExp(r'\.[^/.]+$'), ''),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.style} · ${item.processingTime.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(
            duration: 300.ms,
            delay: (index * 40).ms,
          ),
    );
  }

  Widget _buildThumbnail(HistoryItem item) {
    final path = item.thumbnailPath;
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _thumbPlaceholder(),
        );
      }
    }
    // Fallback: show icon placeholder
    return _thumbPlaceholder();
  }

  Widget _thumbPlaceholder() => Container(
        color: AppColors.surfaceElevated,
        child: const Icon(Icons.movie_creation_outlined,
            color: AppColors.textMuted, size: 32),
      );

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded,
                color: AppColors.textPrimary),
            title: const Text('Open',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              onTap();
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No renders yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Render a photo to see it here',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ).animate().fadeIn(),
      );
}
