import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers/habit_provider.dart';
import '../main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bgShift;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoTurns;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  bool _effectsEnabled = false;

  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _bgShift = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.45, curve: Curves.easeOut),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.86, end: 1.06).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 40,
      ),
    ]).animate(_controller);

    _logoTurns = Tween<double>(begin: -0.02, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.9, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNext();
      }
    });

    // Start after the first frame so the user sees the full animation
    // (otherwise the OS splash can hide the first part on cold starts).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_controller.isAnimating || _controller.isCompleted) return;

      // Show a quick, lightweight "affirmation" frame first.
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;

      if (!_effectsEnabled) {
        setState(() {
          _effectsEnabled = true;
        });
      }

      // Start the full animation after the effects frame is on-screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.isAnimating || _controller.isCompleted) return;
        _controller.forward();
      });
    });
  }

  Future<void> _navigateToNext() async {
    if (_didNavigate) return;
    _didNavigate = true;

    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;

    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.32);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.22);

    // Make the very first Flutter frame lightweight so Android can drop the
    // native launch background ASAP. We enable the full effects right after
    // the first frame and then run the animation.
    if (!_effectsEnabled) {
      return Scaffold(
        backgroundColor: bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Atobits',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '“Consistency beats intensity.”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Build habits that stick.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: SafeArea(
                top: false,
                child: Text(
                  'AI-powered habit tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: secondaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _bgShift.value;

          final accent1 = primaryBlue.withValues(alpha: isDark ? 0.38 : 0.18);
          final accent2 = primaryBlue.withValues(alpha: isDark ? 0.18 : 0.10);

          final g1 = Color.lerp(bg, accent1, 0.85) ?? bg;
          final g2 = Color.lerp(bg, accent2, 0.65) ?? bg;

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.9 + 0.4 * t, -1.0),
                    end: Alignment(0.9 - 0.3 * t, 1.0),
                    colors: [g1, bg, g2],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              CustomPaint(
                painter: _SplashOrbsPainter(
                  t: t,
                  isDark: isDark,
                  primaryBlue: primaryBlue,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: RotationTransition(
                          turns: _logoTurns,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 18,
                                sigmaY: 18,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: glassColor,
                                  borderRadius: BorderRadius.circular(34),
                                  border: Border.all(color: glassBorder),
                                ),
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color.lerp(
                                              primaryBlue,
                                              Colors.white,
                                              isDark ? 0.06 : 0.18,
                                            ) ??
                                            primaryBlue,
                                        Color.lerp(
                                              primaryBlue,
                                              Colors.black,
                                              isDark ? 0.22 : 0.08,
                                            ) ??
                                            primaryBlue,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryBlue.withValues(
                                          alpha: isDark ? 0.40 : 0.28,
                                        ),
                                        blurRadius: 34,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 56,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Text(
                          'Atobits',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: SafeArea(
                  top: false,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      'AI-powered habit tracker',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashOrbsPainter extends CustomPainter {
  const _SplashOrbsPainter({
    required this.t,
    required this.isDark,
    required this.primaryBlue,
  });

  final double t;
  final bool isDark;
  final Color primaryBlue;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide;

    final p1 = Offset(
      size.width * (0.18 + 0.08 * math.sin(t * math.pi * 2)),
      size.height * (0.25 + 0.06 * math.cos(t * math.pi * 2)),
    );
    final p2 = Offset(
      size.width * (0.92 - 0.10 * math.cos(t * math.pi * 2)),
      size.height * (0.18 + 0.08 * math.sin(t * math.pi * 2)),
    );
    final p3 = Offset(
      size.width * (0.55 + 0.08 * math.sin(t * math.pi * 4)),
      size.height * (0.92 - 0.10 * math.cos(t * math.pi * 2)),
    );

    final a1 = isDark ? 0.20 : 0.14;
    final a2 = isDark ? 0.14 : 0.10;

    _drawOrb(
      canvas,
      center: p1,
      radius: r * 0.72,
      color: primaryBlue.withValues(alpha: a1),
    );
    _drawOrb(
      canvas,
      center: p2,
      radius: r * 0.58,
      color: primaryBlue.withValues(alpha: a2),
    );
    _drawOrb(
      canvas,
      center: p3,
      radius: r * 0.66,
      color: primaryBlue.withValues(alpha: a2),
    );
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _SplashOrbsPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primaryBlue != primaryBlue;
  }
}
