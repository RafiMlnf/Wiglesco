import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import '../providers/premium_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    // Default to the yearly package (best value)
    _selectedPackageId = 'wiglesco_premium_yearly';
  }

  @override
  Widget build(BuildContext context) {
    final premiumState = ref.watch(premiumProvider);

    ref.listen<PremiumState>(premiumProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(premiumProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Top Gradient Accent Blur ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -1.0), // Top center
                  radius: 1.5,
                  colors: [
                    AppColors.gradientStart.withOpacity(0.18),
                    Colors.transparent, // Smooth fade out to transparent
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),

          // ── Main Scrollable Content ───────────────────────────────────────
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(height: 12),

                // Premium Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/crown.png',
                        color: Colors.amber,
                        colorBlendMode: BlendMode.srcIn,
                        width: 58,
                        height: 58,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: const Color(0xFFFFD700), // Gold
                              highlightColor: const Color(0xFFFFFDF0), // Shiny light gold
                              child: const Text(
                                'Wiglesco Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Unlock unlimited 3D parallax generation',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Benefit List
                const _BenefitRow(
                  icon: Icons.flash_on_rounded,
                  title: 'Fast GPU Rendering',
                  description: 'Skip the line and process 3D parallax on cloud server in 10-15 seconds.',
                ),
                const SizedBox(height: 16),
                const _BenefitRow(
                  icon: Icons.all_inclusive_rounded,
                  title: 'Unlimited Daily Generations',
                  description: 'No daily limit resets. Render as many stereograms and wigglegrams as you wish.',
                ),
                const SizedBox(height: 16),
                const _BenefitRow(
                  icon: Icons.hd_rounded,
                  title: 'Full HD Export Formats',
                  description: 'Save output videos (MP4) and animations (GIF) in crisp, native resolution.',
                ),
                const SizedBox(height: 16),
                const _BenefitRow(
                  icon: Icons.style_rounded,
                  title: 'Unlock Premium Filters & Presets',
                  description: 'Access exclusive camera presets (Nishika, N8000) and Analog color grading.',
                ),
                const SizedBox(height: 36),

                // Plan selection list
                const Text(
                  'CHOOSE A PLAN',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                ...premiumState.availablePackages.map((package) {
                  final isSelected = _selectedPackageId == package.id;
                  final isYearly = package.id.contains('yearly');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPackageId = package.id;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceElevated
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gradientStart
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected
                                  ? AppColors.gradientStart
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        package.title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (isYearly) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.amber.withOpacity(0.3),
                                            ),
                                          ),
                                          child: const Text(
                                            'SAVE 45%',
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    package.description,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  package.priceString,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '/${package.period}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // CTA Button (Glassmorphism + Shimmering Gold Border)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Stack(
                      children: [
                        // Base glassmorphic background & content
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: (_selectedPackageId == null)
                                ? Colors.white.withOpacity(0.02)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: premiumState.isLoading || _selectedPackageId == null
                                ? null
                                : () async {
                                    final success = await ref
                                        .read(premiumProvider.notifier)
                                        .purchasePackage(_selectedPackageId!);
                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Thank you! Wiglesco Premium Active!'),
                                          backgroundColor: Colors.greenAccent,
                                        ),
                                      );
                                      context.pop();
                                    }
                                  },
                            child: Center(
                              child: premiumState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'ACTIVATE PREMIUM ACCESS',
                                      style: TextStyle(
                                        color: _selectedPackageId == null
                                            ? Colors.white38
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        // Shimmering Gold Border overlay
                        if (_selectedPackageId != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Shimmer.fromColors(
                                baseColor: const Color(0xFFFFD700), // Gold border base
                                highlightColor: const Color(0xFFFFFDF0), // Shiny light gold highlight
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent, // Only border shimmers
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white, // Masked by shimmer
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          // Disabled state border (no shimmer, just dark/translucent)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Purchases successfully restored.'),
                          ),
                        );
                      },
                      child: const Text(
                        'Restore Purchases',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '•',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Terms & Privacy Policy',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            color: AppColors.gradientStart,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
