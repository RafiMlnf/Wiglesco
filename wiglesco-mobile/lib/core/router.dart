import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../models/history_item.dart';
import '../screens/home_screen.dart';
import '../screens/editor_screen.dart';
import '../screens/result_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/paywall_screen.dart';
import '../core/theme.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    // Full-screen routes (no bottom nav)
    GoRoute(
      path: '/editor',
      builder: (context, state) => const EditorScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        final item = state.extra as HistoryItem;
        return ResultScreen(item: item);
      },
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
  ],
);

// ── Shell Scaffold ─────────────────────────────────────────────────────────────

class _ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const _ScaffoldWithNavBar({super.key, required this.child});

  int _locationToIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _locationToIndex(context);
    return Scaffold(
      extendBody: true, // allows content to go under the floating bar
      body: child,
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/history');
              break;
            case 2:
              context.go('/settings');
              break;
          }
        },
      ),
    );
  }
}

// ── Floating Glassmorphism Nav Bar ─────────────────────────────────────────────

class _FloatingNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _idleController;
  int _prevIndex = 0;
  int _currentIndex = 0;

  // Cached noise points for performance
  List<Offset>? _cachedPoints;
  double _cachedWidth = 0.0;
  double _cachedHeight = 0.0;

  List<Offset> _getNoisePoints(double width, double height) {
    if (_cachedPoints != null &&
        _cachedWidth == width &&
        _cachedHeight == height) {
      return _cachedPoints!;
    }
    // Seeded Random so the noise pattern is static and doesn't flicker/regenerate
    final r = math.Random(1337);
    _cachedPoints = List.generate(1200, (_) {
      return Offset(r.nextDouble() * width, r.nextDouble() * height);
    });
    _cachedWidth = width;
    _cachedHeight = height;
    return _cachedPoints!;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _prevIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Smooth stretching duration (0.6s)
    );
    _controller.value = 1.0; // start fully animated
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(_FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex) {
      setState(() {
        _prevIndex = _currentIndex;
        _currentIndex = widget.selectedIndex;
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            // Thin adaptive blur
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                final totalWidth = outerConstraints.maxWidth;
                // Pre-generate noise points for the current outer size
                final noisePoints = _getNoisePoints(totalWidth, 72.0);

                return _GlassShell(
                  noisePoints: noisePoints,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: LayoutBuilder(
                      // Inner LayoutBuilder ensures we get the EXACT width of the inner Stack
                      builder: (context, innerConstraints) {
                        final innerWidth = innerConstraints.maxWidth;
                        final tabWidth = innerWidth / 3;
                        const pillWidth = 46.0; // Perfect circle when static
                        const pillHeight = 46.0;

                        // Determine stretch directions
                        final movingRight = _currentIndex > _prevIndex;

                        // Leading edge moves first, trailing edge starts when leading is almost done
                        final Curve leftCurve = movingRight
                            ? const Interval(0.45, 1.0, curve: Curves.easeInOutSine)
                            : const Interval(0.0, 0.55, curve: Curves.easeInOutSine);

                        final Curve rightCurve = movingRight
                            ? const Interval(0.0, 0.55, curve: Curves.easeInOutSine)
                            : const Interval(0.45, 1.0, curve: Curves.easeInOutSine);

                        return Stack(
                          children: [
                            // ── Sliding Stretching Pill ──
                            AnimatedBuilder(
                              animation: Listenable.merge([_controller, _idleController]),
                              builder: (context, child) {
                                final t = _controller.value;
                                final idleVal = _idleController.value;

                                // Balloon-like vertical swelling in the middle of transition
                                final swell = math.sin(t * math.pi);
                                final baseHeight = pillHeight + (swell * 8.0);

                                // Idle weight (1.0 at rest, 0.0 in the middle of transition)
                                final idleWeight = (1.0 - swell).clamp(0.0, 1.0);

                                // Smooth sinusoidal idle floating wiggles (horizontal & vertical)
                                final idleX = (math.sin(idleVal * 2.0 * math.pi) * 2.0 +
                                        math.cos(idleVal * 3.0 * math.pi) * 0.8) *
                                    idleWeight;
                                final idleY = (math.cos(idleVal * 2.0 * math.pi) * 1.5 +
                                        math.sin(idleVal * 4.0 * math.pi) * 0.5) *
                                    idleWeight;

                                final currentHeight = baseHeight +
                                    (math.sin(idleVal * 2.0 * math.pi) * 1.2 * idleWeight);

                                final leftStart = _prevIndex * tabWidth + (tabWidth - pillWidth) / 2;
                                final leftTarget = _currentIndex * tabWidth + (tabWidth - pillWidth) / 2;

                                final rightStart = (2 - _prevIndex) * tabWidth + (tabWidth - pillWidth) / 2;
                                final rightTarget = (2 - _currentIndex) * tabWidth + (tabWidth - pillWidth) / 2;

                                final currentLeft = leftStart +
                                    (leftTarget - leftStart) * leftCurve.transform(t) +
                                    idleX;
                                final currentRight = rightStart +
                                    (rightTarget - rightStart) * rightCurve.transform(t) -
                                    idleX;

                                return Positioned(
                                  left: currentLeft,
                                  right: currentRight,
                                  top: (56.0 - currentHeight) / 2 + idleY,
                                  height: currentHeight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      // Frosted active indicator swells/opacity pulses
                                      color: Colors.white.withOpacity(0.12 + swell * 0.08),
                                      borderRadius: BorderRadius.circular(currentHeight / 2),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.24 + swell * 0.16),
                                        width: 1.0 + swell * 0.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // ── Tab Icons ──
                            // Wrapped in Expanded to divide width perfectly and center the icons precisely
                            Row(
                              children: [
                                Expanded(
                                  child: _NavItem(
                                    icon: Icons.home_outlined,
                                    selectedIcon: Icons.home_rounded,
                                    isSelected: _currentIndex == 0,
                                    onTap: () => widget.onDestinationSelected(0),
                                  ),
                                ),
                                Expanded(
                                  child: _NavItem(
                                    icon: Icons.history_outlined,
                                    selectedIcon: Icons.history_rounded,
                                    isSelected: _currentIndex == 1,
                                    onTap: () => widget.onDestinationSelected(1),
                                  ),
                                ),
                                Expanded(
                                  child: _NavItem(
                                    icon: Icons.settings_outlined,
                                    selectedIcon: Icons.settings_rounded,
                                    isSelected: _currentIndex == 2,
                                    onTap: () => widget.onDestinationSelected(2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass Shell with Adaptive Frosted Noise ────────────────────────────────────

class _GlassShell extends StatelessWidget {
  final Widget child;
  final List<Offset> noisePoints;

  const _GlassShell({required this.child, required this.noisePoints});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Lighter frosted glass look using linear semi-transparent white gradient
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // ── Shimmering Light Sweep ──
          Positioned.fill(
            child: IgnorePointer(
              child: Shimmer.fromColors(
                baseColor: Colors.transparent,
                highlightColor: Colors.white.withOpacity(0.08),
                period: const Duration(seconds: 4),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Adaptive Frosted Noise Overlay ──
          Positioned.fill(
            child: CustomPaint(
              painter: _FrostedNoisePainter(
                points: noisePoints,
                opacity: 0.15, // strength of the noise
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Custom Painter for Adaptive Noise ──

class _FrostedNoisePainter extends CustomPainter {
  final List<Offset> points;
  final double opacity;

  _FrostedNoisePainter({required this.points, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square
      ..blendMode = BlendMode.overlay; // Adaptive Blend Mode!

    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant _FrostedNoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.points != points;
  }
}

// ── Nav Item ───────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              key: ValueKey(isSelected),
              color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.45),
              size: 28, // Enlarged icon size
            ),
          ),
        ),
      ),
    );
  }
}
