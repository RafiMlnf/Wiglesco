import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../providers/editor_provider.dart';

class ControlPanel extends StatelessWidget {
  final EditorState state;
  final EditorNotifier notifier;

  const ControlPanel({
    super.key,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Parallax & Frame Rate ─────────────────────────────────────────
          _ControlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Label('Parallax Displacement'),
                    const Spacer(),
                    _Value(state.parallaxStrength.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  value: state.parallaxStrength,
                  min: 0.1,
                  max: 1.0,
                  onChanged: notifier.setStrength,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                Row(
                  children: [
                    const _Label('Frame Rate'),
                    const Spacer(),
                    _Value('${state.fps} fps'),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  value: state.fps.toDouble(),
                  min: 6,
                  max: 30,
                  onChanged: (v) => notifier.setFps(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Frames ────────────────────────────────────────────────────────
          _ControlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Frames'),
                const SizedBox(height: 10),
                Row(
                  children: kFrameOptions.map((f) {
                    final active = state.numFrames == f;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => notifier.setFrames(f),
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
                              '$f',
                              style: TextStyle(
                                color: active
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Style Preset ──────────────────────────────────────────────────
          _ControlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Style Preset'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: kStyleKeys.map((key) {
                      final active = state.effectStyle == key;
                      return GestureDetector(
                        onTap: () => notifier.setStyle(key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
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
                              (kStyleLabels[key] ?? key).toUpperCase(),
                              style: TextStyle(
                                color: active
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                letterSpacing: 0.5,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Format ────────────────────────────────────────────────────────
          _ControlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Export Format'),
                const SizedBox(height: 10),
                Row(
                  children: kFormatOptions.map((f) {
                    final active = state.exportFormat == f;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => notifier.setFormat(f),
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
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  final Widget child;
  const _ControlCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _Value extends StatelessWidget {
  final String text;
  const _Value(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
}
