import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FireworksShowScene extends StatefulWidget {
  const FireworksShowScene({super.key});

  @override
  State<FireworksShowScene> createState() => _FireworksShowSceneState();
}

class _FireworksShowSceneState extends State<FireworksShowScene>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  final List<_FireworkParticle> _particles = <_FireworkParticle>[];
  final List<_Shockwave> _waves = <_Shockwave>[];
  List<_Star> _stars = const <_Star>[];

  late final Ticker _ticker;
  Duration _previousElapsed = Duration.zero;
  Size _viewport = Size.zero;
  bool _autoLaunch = true;
  double _autoLaunchCountdown = 0.8;
  int _burstCount = 0;
  bool _seededInitialShow = false;
  double _launchTopInset = 140;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_previousElapsed == Duration.zero) {
      _previousElapsed = elapsed;
      return;
    }

    final micros = (elapsed - _previousElapsed).inMicroseconds;
    _previousElapsed = elapsed;
    final dt = (micros / Duration.microsecondsPerSecond).clamp(0.0, 0.05);

    for (final particle in _particles) {
      particle.step(dt);
    }
    _particles.removeWhere((particle) => particle.isDead);

    for (final wave in _waves) {
      wave.step(dt);
    }
    _waves.removeWhere((wave) => wave.isDead);

    if (_autoLaunch && _viewport != Size.zero) {
      _autoLaunchCountdown -= dt;
      if (_autoLaunchCountdown <= 0) {
        _launchAutoBurst();
        _autoLaunchCountdown = 0.75 + _random.nextDouble() * 1.1;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _launchAutoBurst() {
    if (_viewport == Size.zero) {
      return;
    }

    final point = Offset(
      _viewport.width * (0.18 + _random.nextDouble() * 0.64),
      _launchTopInset + _viewport.height * (0.12 + _random.nextDouble() * 0.24),
    );
    _spawnBurst(point, intensity: 0.95 + _random.nextDouble() * 0.4);
  }

  void _spawnBurst(Offset point, {double intensity = 1.0}) {
    final minX = 24.0;
    final maxX = math.max(minX, _viewport.width - 24.0);
    final minY = _launchTopInset;
    final maxY = math.max(minY, _viewport.height - 80.0);
    final burstPoint = Offset(
      point.dx.clamp(minX, maxX),
      point.dy.clamp(minY, maxY),
    );
    final palette = _palettes[_random.nextInt(_palettes.length)];
    final count = ((28 + _random.nextInt(16)) * intensity).round();
    final baseSpeed = 90 + _random.nextDouble() * 40;

    _waves.add(
      _Shockwave(center: burstPoint, color: palette.first, maxAge: 0.65),
    );

    for (var i = 0; i < count; i++) {
      final angle = (_random.nextDouble() * math.pi * 2);
      final speed = baseSpeed + _random.nextDouble() * 190;
      final velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
      final color = palette[_random.nextInt(palette.length)];

      _particles.add(
        _FireworkParticle(
          position: burstPoint,
          velocity: velocity,
          color: color,
          radius: 1.4 + _random.nextDouble() * 2.8,
          maxLife: 0.9 + _random.nextDouble() * 0.9,
          shimmerPhase: _random.nextDouble() * math.pi * 2,
          drag: 0.972 + _random.nextDouble() * 0.014,
        ),
      );
    }

    for (var i = 0; i < 8; i++) {
      final angle = (_random.nextDouble() * math.pi * 2);
      final speed = 220 + _random.nextDouble() * 140;
      _particles.add(
        _FireworkParticle(
          position: burstPoint,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color: palette[i % palette.length],
          radius: 2.8 + _random.nextDouble() * 1.8,
          maxLife: 1.1 + _random.nextDouble() * 0.5,
          shimmerPhase: _random.nextDouble() * math.pi * 2,
          drag: 0.982,
        ),
      );
    }

    _burstCount++;
  }

  void _clearShow() {
    setState(() {
      _particles.clear();
      _waves.clear();
    });
  }

  void _toggleAutoLaunch() {
    setState(() {
      _autoLaunch = !_autoLaunch;
      _autoLaunchCountdown = 0.4;
    });
  }

  void _refreshViewport(Size size) {
    if ((_viewport.width - size.width).abs() < 1 &&
        (_viewport.height - size.height).abs() < 1) {
      return;
    }

    _viewport = size;
    _stars = _buildStars(size);

    if (!_seededInitialShow && size != Size.zero) {
      _seededInitialShow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _launchAutoBurst();
        _launchAutoBurst();
        _launchAutoBurst();
      });
    }
  }

  List<_Star> _buildStars(Size size) {
    final stars = <_Star>[];
    final count = math.max(48, (size.width / 18).floor());

    for (var i = 0; i < count; i++) {
      stars.add(
        _Star(
          position: Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height * 0.78,
          ),
          radius: 0.7 + _random.nextDouble() * 1.7,
          opacity: 0.18 + _random.nextDouble() * 0.5,
        ),
      );
    }

    return stars;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        _launchTopInset = topPadding + 108;
        _refreshViewport(Size(constraints.maxWidth, constraints.maxHeight));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            setState(() {
              _spawnBurst(details.localPosition);
            });
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _FireworksPainter(
                      particles: _particles,
                      waves: _waves,
                      stars: _stars,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 84, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '烟花秀',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '轻触屏幕，尽情庆祝。',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已点亮 $_burstCount 束烟花',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filled(
                            onPressed: _launchAutoBurst,
                            icon: const Icon(Icons.rocket_launch),
                            tooltip: '再来一束',
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: _toggleAutoLaunch,
                            icon: Icon(
                              _autoLaunch
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                            ),
                            tooltip: _autoLaunch ? '暂停自动烟花' : '恢复自动烟花',
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: _clearShow,
                            icon: const Icon(Icons.layers_clear),
                            tooltip: '清空画面',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FireworksPainter extends CustomPainter {
  const _FireworksPainter({
    required this.particles,
    required this.waves,
    required this.stars,
  });

  final List<_FireworkParticle> particles;
  final List<_Shockwave> waves;
  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050816), Color(0xFF130A2B), Color(0xFF291236)],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    for (final star in stars) {
      canvas.drawCircle(
        star.position,
        star.radius,
        Paint()..color = Colors.white.withValues(alpha: star.opacity),
      );
    }

    final skyline = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xAA090B16), Color(0xFF04050A)],
            stops: [0, 0.75, 1],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.55,
              size.width,
              size.height * 0.45,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      skyline,
    );

    for (final wave in waves) {
      final progress = wave.age / wave.maxAge;
      final radius = lerpDouble(12, 120, progress);
      final opacity = (1 - progress) * 0.42;

      canvas.drawCircle(
        wave.center,
        radius,
        Paint()
          ..color = wave.color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 - progress,
      );
    }

    for (final particle in particles) {
      final progress = particle.life / particle.maxLife;
      final shimmer =
          0.68 +
          0.32 * math.sin((1 - progress) * 12 + particle.shimmerPhase).abs();
      final alpha = progress * shimmer;

      for (var i = 0; i < particle.trail.length - 1; i++) {
        final start = particle.trail[i];
        final end = particle.trail[i + 1];
        final segmentAlpha = alpha * (1 - (i / particle.trail.length)) * 0.45;
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = particle.color.withValues(alpha: segmentAlpha)
            ..strokeWidth =
                particle.radius * (1.1 - (i / particle.trail.length) * 0.7)
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.drawCircle(
        particle.position,
        particle.radius * 2.4,
        Paint()..color = particle.color.withValues(alpha: alpha * 0.16),
      );
      canvas.drawCircle(
        particle.position,
        particle.radius,
        Paint()..color = particle.color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) {
    return true;
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

class _FireworkParticle {
  _FireworkParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    required this.maxLife,
    required this.shimmerPhase,
    required this.drag,
  }) : life = maxLife;

  Offset position;
  Offset velocity;
  final Color color;
  final double radius;
  final double maxLife;
  final double shimmerPhase;
  final double drag;
  double life;
  final List<Offset> trail = <Offset>[];

  bool get isDead => life <= 0;

  void step(double dt) {
    trail.insert(0, position);
    if (trail.length > 10) {
      trail.removeLast();
    }

    velocity = Offset(velocity.dx * drag, velocity.dy * drag + 180 * dt);
    position = Offset(
      position.dx + velocity.dx * dt,
      position.dy + velocity.dy * dt,
    );
    life -= dt;
  }
}

class _Shockwave {
  _Shockwave({required this.center, required this.color, required this.maxAge});

  final Offset center;
  final Color color;
  final double maxAge;
  double age = 0;

  bool get isDead => age >= maxAge;

  void step(double dt) {
    age += dt;
  }
}

class _Star {
  const _Star({
    required this.position,
    required this.radius,
    required this.opacity,
  });

  final Offset position;
  final double radius;
  final double opacity;
}

const List<List<Color>> _palettes = [
  [Color(0xFFFFD166), Color(0xFFFF7A18), Color(0xFFFF3D81)],
  [Color(0xFF7AF5FF), Color(0xFF52B6FF), Color(0xFF6C63FF)],
  [Color(0xFF9BFF9F), Color(0xFF35E0A1), Color(0xFF00C2FF)],
  [Color(0xFFFF95C8), Color(0xFFFF5F6D), Color(0xFFFFC371)],
];
