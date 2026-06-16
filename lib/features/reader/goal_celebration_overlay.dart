import 'dart:math';
import 'package:flutter/material.dart';

class GoalCelebrationOverlay extends StatefulWidget {
  final int streakDays;
  const GoalCelebrationOverlay({super.key, required this.streakDays});

  @override
  State<GoalCelebrationOverlay> createState() => _GoalCelebrationOverlayState();
}

class _Particle {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double wobble;
  _Particle(Random rng)
    : x = (rng.nextDouble() - 0.5) * 120,
      speed = 0.6 + rng.nextDouble() * 0.4,
      size = 3 + rng.nextDouble() * 4,
      wobble = (rng.nextDouble() - 0.5) * 40,
      color = Color.lerp(
        Colors.orange,
        Colors.deepOrange,
        rng.nextDouble(),
      )!.withValues(alpha: 0.9);
}

class _GoalCelebrationOverlayState extends State<GoalCelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late AnimationController _flameController;

  late Animation<double> _fadeIn;
  late Animation<Color?> _flameColor;
  late Animation<Color?> _borderColor;
  late Animation<double> _oldNumberSlide;
  late Animation<double> _oldNumberFade;
  late Animation<double> _newNumberSlide;
  late Animation<double> _newNumberFade;
  late Animation<double> _particleFade;
  late Animation<double> _glowRadius;
  late Animation<double> _pulse;
  late Animation<double> _flameWobble;

  final List<_Particle> _particles = List.generate(
    14,
    (_) => _Particle(Random()),
  );

  int get _oldStreak => (widget.streakDays - 1).clamp(0, 999);
  int get _newStreak => widget.streakDays;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
    );

    _flameColor = ColorTween(begin: Colors.white30, end: Colors.orange).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.65, curve: Curves.easeInOut),
      ),
    );

    _borderColor =
        ColorTween(
          begin: Colors.white12,
          end: Colors.orange.withValues(alpha: 0.7),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.65, curve: Curves.easeInOut),
          ),
        );

    _particleFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.85, curve: Curves.easeIn),
      ),
    );

    _glowRadius = Tween<double>(begin: 0.0, end: 16.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
      ),
    );

    _oldNumberSlide = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.72, curve: Curves.easeIn),
      ),
    );
    _oldNumberFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.70, curve: Curves.easeIn),
      ),
    );
    _newNumberSlide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.62, 0.88, curve: Curves.elasticOut),
      ),
    );
    _newNumberFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.62, 0.80, curve: Curves.easeOut),
      ),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _flameWobble = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOut),
    );

    _controller.forward();
    _controller.addListener(() {
      if (_controller.value >= 0.6 && !_pulseController.isAnimating) {
        _pulseController.forward().then((_) => _pulseController.reverse());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _pulseController,
          _flameController,
        ]),
        builder: (context, _) {
          final particleProgress =
              (_controller.value - 0.25).clamp(0.0, 0.6) / 0.6;

          return Center(
            child: Transform.scale(
              scale: _pulse.value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _borderColor.value ?? Colors.white12,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(
                        alpha:
                            0.15 *
                            (_controller.value.clamp(0.3, 1.0) - 0.3) /
                            0.7,
                      ),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Partikel
                    if (particleProgress > 0 && _particleFade.value > 0)
                      ..._particles.map((p) {
                        final dy = -particleProgress * 80 * p.speed;
                        final dx = p.wobble * particleProgress;
                        return Positioned(
                          top: 0 + dy,
                          left: 60 + p.x + dx,
                          child: Opacity(
                            opacity:
                                (_particleFade.value *
                                        (1 - particleProgress * 0.5))
                                    .clamp(0.0, 1.0),
                            child: Container(
                              width: p.size,
                              height: p.size,
                              decoration: BoxDecoration(
                                color: p.color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: p.color.withValues(alpha: 0.6),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    // Hauptinhalt
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: _flameWobble.value,
                              child: Icon(
                                Icons.local_fire_department,
                                color: _flameColor.value ?? Colors.white30,
                                size: 44,
                                shadows: _glowRadius.value > 0
                                    ? [
                                        Shadow(
                                          color: Colors.orange.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: _glowRadius.value,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 68,
                              height: 52,
                              child: ClipRect(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        _oldNumberSlide.value * 52,
                                      ),
                                      child: Opacity(
                                        opacity: _oldNumberFade.value,
                                        child: Text(
                                          '$_oldStreak',
                                          style: TextStyle(
                                            color:
                                                _flameColor.value ??
                                                Colors.white30,
                                            fontSize: 38,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        _newNumberSlide.value * 52,
                                      ),
                                      child: Opacity(
                                        opacity: _newNumberFade.value,
                                        child: Text(
                                          '$_newStreak',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 38,
                                            fontWeight: FontWeight.bold,
                                            shadows: _glowRadius.value > 0
                                                ? [
                                                    Shadow(
                                                      color: Colors.orange
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      blurRadius:
                                                          _glowRadius.value,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tagesziel erreicht!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '5.000 Wörter',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
