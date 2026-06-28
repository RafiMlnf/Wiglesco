import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/theme.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';

final connectionTestProvider = StateProvider.autoDispose<String?>((ref) => null);
final connectionTestingProvider = StateProvider.autoDispose<bool>((ref) => false);

Future<void> _testConnection(WidgetRef ref, String url) async {
  ref.read(connectionTestingProvider.notifier).state = true;
  ref.read(connectionTestProvider.notifier).state = null;

  try {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ));
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final response = await dio.get(cleanUrl);
    
    if (response.statusCode == 200) {
      ref.read(connectionTestProvider.notifier).state = 'Connected! API is active.';
    } else {
      ref.read(connectionTestProvider.notifier).state = 'Failed (Status: ${response.statusCode})';
    }
  } catch (e) {
    ref.read(connectionTestProvider.notifier).state = 'Connection failed: ${e.toString().split('\n').first}';
  } finally {
    ref.read(connectionTestingProvider.notifier).state = false;
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final isTesting = ref.watch(connectionTestingProvider);
    final testResult = ref.watch(connectionTestProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          // ── Mode Switcher Card ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented Toggle Buttons
                Container(
                  height: 42,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // SERVERLESS Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref
                              .read(settingsProvider.notifier)
                              .setServerMode(false),
                          child: Container(
                            decoration: BoxDecoration(
                              color: !settings.useServerMode
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'SERVERLESS',
                                style: TextStyle(
                                  color: !settings.useServerMode
                                      ? Colors.black
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // SERVER Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref
                              .read(settingsProvider.notifier)
                              .setServerMode(true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: settings.useServerMode
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'SERVER',
                                style: TextStyle(
                                  color: settings.useServerMode
                                      ? Colors.black
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: AppColors.border, height: 1),
                ),

                // 2x2 Details Grid
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'PROCESSOR',
                        value: settings.useServerMode
                            ? 'GPU Server'
                            : 'On-Device CPU/GPU',
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'AI MODEL',
                        value: settings.useServerMode
                            ? 'FastAPI Pipeline'
                            : 'DepthAnythingV2',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'INTERNET',
                        value: settings.useServerMode ? 'Required' : '100% Offline',
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'DATA PRIVACY',
                        value: settings.useServerMode
                            ? 'Sent to Server'
                            : 'Local Only',
                      ),
                    ),
                  ],
                ),

                if (settings.useServerMode) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(color: AppColors.border, height: 1),
                  ),
                  const Text(
                    'SERVER ENDPOINT URL',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextFormField(
                            initialValue: settings.serverUrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              border: InputBorder.none,
                              hintText: 'http://10.0.2.2:8000',
                              hintStyle: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            onChanged: (val) {
                              ref.read(settingsProvider.notifier).setServerUrl(val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.08),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          onPressed: isTesting
                              ? null
                              : () => _testConnection(ref, settings.serverUrl),
                          child: isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'TEST',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      testResult,
                      style: TextStyle(
                        color: testResult.startsWith('Connected')
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Pipeline Info ────────────────────────────────────────────────
          _SectionHeader('AI Pipeline'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _PipelineStep(
                    icon: Icons.image_outlined,
                    label: 'Preprocess',
                    detail: 'Resize to 512px (Dart)'),
                _PipelineStep(
                    icon: Icons.view_in_ar_rounded,
                    label: 'Depth Estimation',
                    detail: 'Depth Anything V2 Small (ONNX Runtime)'),
                _PipelineStep(
                    icon: Icons.animation_rounded,
                    label: 'Parallax Synthesis',
                    detail: "3D warp + Painter's Algorithm (Dart)"),
                _PipelineStep(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Style Effects',
                    detail: 'Color grading · Grain · Vignette (Dart)'),
                _PipelineStep(
                    icon: Icons.video_file_rounded,
                    label: 'Video Export',
                    detail: 'MP4 / GIF (FFmpeg Kit)',
                    isLast: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Storage ──────────────────────────────────────────────────────
          _SectionHeader('Storage'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.error, size: 22),
              title: Text(
                'Clear Render History (${history.length})',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
              ),
              subtitle: Text('Remove all saved renders from history',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted, size: 14),
              onTap: () => _confirmClearHistory(context, ref),
            ),
          ),

          const SizedBox(height: 24),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader('About'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                _AboutRow('App', 'Wiglesco Mobile'),
                Divider(color: AppColors.border, height: 20),
                _AboutRow('Version', '1.0.0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
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
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );
}

class _PipelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool isLast;
  const _PipelineStep(
      {required this.icon,
      required this.label,
      required this.detail,
      this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryLight, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Text(detail,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(color: AppColors.border, height: 1),
        ],
      );
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      );
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
