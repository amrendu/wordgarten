import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// A finite entrance animation; reduced motion shows the completed garden.
class GrowingGarden extends StatefulWidget {
  const GrowingGarden({
    super.key,
    this.brand = false,
    this.size = 240,
    this.entrance,
  });
  final bool brand;
  final double size;
  final Animation<double>? entrance;
  @override
  State<GrowingGarden> createState() => _GrowingGardenState();
}

class _GrowingGardenState extends State<GrowingGarden>
    with SingleTickerProviderStateMixin {
  AnimationController? _animation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.entrance != null) return;
    final animation = _animation ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.value = 1;
    } else if (animation.status == AnimationStatus.dismissed) {
      animation.forward();
    }
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.size,
      height: widget.size * .86,
      child: AnimatedBuilder(
        animation: widget.entrance ?? _animation!,
        builder: (context, _) {
          final progress = (widget.entrance ?? _animation!).value;
          final t = Curves.easeOutCubic.transform(progress);
          if (widget.brand) {
            final settle = _stage(progress, 0, .74, Curves.easeOutCubic);
            final scale = _stage(progress, 0, .76, Curves.easeOutBack);
            final markSize = widget.size * .52;
            final initialScale = (128 / markSize).clamp(.75, 1.0);
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _stage(progress, .04, .65),
                  child: Transform.scale(
                    scale: .8 + .2 * settle,
                    child: Container(
                      width: widget.size * .83,
                      height: widget.size * .83,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFFDDEBDA), Garden.background],
                        ),
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size(widget.size, widget.size * .86),
                  painter: _LogoGardenPainter(progress),
                ),
                Transform.translate(
                  offset: Offset(0, widget.size * .28 * (1 - settle)),
                  child: Transform.rotate(
                    angle: -.035 * math.sin(math.pi * settle),
                    child: Transform.scale(
                      scale: initialScale + (1 - initialScale) * scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Garden.green,
                          borderRadius: BorderRadius.circular(markSize * .28),
                          boxShadow: [
                            BoxShadow(
                              color: Garden.ink.withValues(alpha: .10 * settle),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: BrandMark(size: markSize),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * .79,
                height: widget.size * .79,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Garden.mint, Garden.background],
                  ),
                ),
              ),
              CustomPaint(
                size: Size(widget.size, widget.size * .86),
                painter: _GardenPainter(t),
              ),
              Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - t)),
                  child: Transform.scale(
                    scale: .86 + .14 * t,
                    child: GardenIllustration(
                      'garden-hero',
                      width: widget.size * .9,
                      height: widget.size * .65,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

double _stage(
  double progress,
  double start,
  double end, [
  Curve curve = Curves.easeOutCubic,
]) => curve.transform(((progress - start) / (end - start)).clamp(0.0, 1.0));

class _LogoGardenPainter extends CustomPainter {
  const _LogoGardenPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final growth = _stage(progress, .04, .73);
    final stem = Paint()
      ..color = Garden.green.withValues(alpha: .32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 150
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(size.width * .5, size.height * .88)
        ..cubicTo(
          size.width * (.5 + side * .40),
          size.height * .91,
          size.width * (.5 + side * .44),
          size.height * .37,
          size.width * (.5 + side * .23),
          size.height * .13,
        );
      final metric = path.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * growth), stem);
      for (var i = 0; i < 5; i++) {
        final fraction = .18 + i * .16;
        if (growth < fraction) continue;
        final tangent = metric.getTangentForOffset(metric.length * fraction)!;
        final leafGrowth = _stage(
          progress,
          .10 + i * .105,
          .36 + i * .105,
          Curves.easeOutBack,
        );
        final length = size.width * (.055 + i * .003);
        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        canvas.rotate(
          math.atan2(tangent.vector.dy, tangent.vector.dx) +
              math.pi / 2 +
              side * .85,
        );
        canvas.scale(leafGrowth);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-length * .58, -length * .6, 0, -length)
          ..quadraticBezierTo(length * .58, -length * .6, 0, 0);
        canvas.drawPath(
          leaf,
          Paint()
            ..color = (i.isEven ? Garden.green : const Color(0xFF89AB83))
                .withValues(alpha: .30),
        );
        canvas.restore();
      }
    }
    for (var i = 0; i < 6; i++) {
      final reveal = _stage(progress, .26 + i * .06, .57 + i * .06);
      final angle = i * math.pi / 3 - math.pi / 2;
      final drift = math.sin(progress * math.pi) * 5;
      final center = Offset(
        size.width * .5 + math.cos(angle) * size.width * .44,
        size.height * .45 + math.sin(angle) * size.height * .38 - drift,
      );
      final paint = Paint()
        ..color = const Color(0xFFD6AD64).withValues(alpha: .55 * reveal)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      if (i.isEven) {
        final radius = 3.8 * reveal;
        canvas.drawLine(
          center - Offset(radius, 0),
          center + Offset(radius, 0),
          paint,
        );
        canvas.drawLine(
          center - Offset(0, radius),
          center + Offset(0, radius),
          paint,
        );
      } else {
        canvas.drawCircle(center, 2 * reveal, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LogoGardenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GardenPainter extends CustomPainter {
  const _GardenPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = Garden.green.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(size.width * .5, size.height * .89)
        ..quadraticBezierTo(
          size.width * (.5 + side * .40),
          size.height * .80,
          size.width * (.5 + side * .36),
          size.height * (.76 - .48 * progress),
        );
      canvas.drawPath(path, stem);
      for (var i = 0; i < 3; i++) {
        final growth = ((progress - i * .14) / .58).clamp(0.0, 1.0);
        final x = size.width * (.5 + side * (.21 + i * .065));
        final y = size.height * (.82 - i * .18);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(side * .7);
        canvas.scale(growth);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-16, -22, 0, -36)
          ..quadraticBezierTo(16, -22, 0, 0);
        canvas.drawPath(
          leaf,
          Paint()..color = Garden.green.withValues(alpha: .16),
        );
        canvas.restore();
      }
    }
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi / 2.5;
      final dot = Offset(
        size.width * .5 + math.cos(a) * size.width * .43,
        size.height * .49 + math.sin(a) * size.height * .40,
      );
      canvas.drawCircle(
        dot,
        2.5 * progress,
        Paint()
          ..color = (i.isEven ? Garden.green : const Color(0xFFD6AD64))
              .withValues(alpha: .45),
      );
    }
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.failed = false,
    this.ready = false,
    this.onRetry,
    this.onFinished,
  });
  final bool failed, ready;
  final VoidCallback? onRetry;
  final VoidCallback? onFinished;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    // 1.4 seconds of motion, then 0.7 seconds to enjoy the finished garden.
    duration: const Duration(milliseconds: 2100),
  );
  late final Animation<double> _gardenEntrance = _entrance.drive(
    CurveTween(curve: const Interval(0, 2 / 3)),
  );
  late final AnimationController _handoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  bool _completionScheduled = false;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    _handoff.addStatusListener((status) {
      if (status == AnimationStatus.completed) _notifyFinished();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (_entrance.status == AnimationStatus.dismissed) {
      _entrance.forward();
    }
    _finish();
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _finish();
  }

  void _finish() {
    if (!widget.ready || widget.failed || _finished) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_completionScheduled) return;
      _completionScheduled = true;
      _handoff.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyFinished();
      });
    } else if (_entrance.isCompleted &&
        !_handoff.isAnimating &&
        !_handoff.isCompleted) {
      _handoff.forward();
    }
  }

  void _notifyFinished() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _handoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: ReverseAnimation(_handoff),
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _SplashBackdropPainter()),
          ),
          SafeArea(
            minimum: EdgeInsets.symmetric(
              horizontal: math.max(
                MediaQuery.paddingOf(context).left,
                MediaQuery.paddingOf(context).right,
              ),
              vertical: math.max(
                MediaQuery.paddingOf(context).top,
                MediaQuery.paddingOf(context).bottom,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math
                    .min(
                      300.0,
                      math.min(
                        constraints.maxWidth - 48,
                        constraints.maxHeight * .43,
                      ),
                    )
                    .clamp(160.0, 300.0);
                return AnimatedBuilder(
                  animation: _gardenEntrance,
                  builder: (context, _) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GrowingGarden(
                              brand: true,
                              size: size,
                              entrance: _gardenEntrance,
                            ),
                            const SizedBox(height: 20),
                            _SplashReveal(
                              progress: _stage(_gardenEntrance.value, .14, .61),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'wortgarten',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontSize: 42,
                                        letterSpacing: -1.5,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _SplashReveal(
                              progress: _stage(_gardenEntrance.value, .29, .76),
                              child: const Text(
                                'Little words. Lasting roots.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Garden.muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _SplashLevelTrail(progress: _gardenEntrance.value),
                            const SizedBox(height: 12),
                            _SplashReveal(
                              progress: _stage(_gardenEntrance.value, .58, .96),
                              child: const Eyebrow(
                                'German vocabulary',
                                color: Garden.green,
                              ),
                            ),
                            if (widget.failed) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Your vocabulary could not open. Please try again.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: widget.onRetry,
                                child: const Text('Try again'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!widget.ready && !widget.failed)
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, _) => Opacity(
                  opacity: _entrance.isCompleted ? 1 : 0,
                  child: Column(
                    children: [
                      if (!MediaQuery.disableAnimationsOf(context))
                        const SizedBox(
                          width: 36,
                          height: 2,
                          child: LinearProgressIndicator(
                            backgroundColor: Garden.mint,
                            color: Garden.green,
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Opening your garden…',
                        style: TextStyle(fontSize: 11, color: Garden.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SplashReveal extends StatelessWidget {
  const _SplashReveal({required this.progress, required this.child});
  final double progress;
  final Widget child;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, 12 * (1 - progress)),
      child: child,
    ),
  );
}

class _SplashLevelTrail extends StatelessWidget {
  const _SplashLevelTrail({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'German vocabulary, levels A1 to C1',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0)
              Opacity(
                opacity: _stage(progress, .34 + i * .08, .57 + i * .08),
                child: Container(width: 10, height: 1, color: Garden.border),
              ),
            _SplashReveal(
              progress: _stage(progress, .34 + i * .08, .64 + i * .08),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: [
                    Garden.mint,
                    Garden.mint,
                    Garden.peach,
                    Garden.lavender,
                    Garden.lavender,
                  ][i],
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  ['A1', 'A2', 'B1', 'B2', 'C1'][i],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Garden.green,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFCFAF3), Garden.background, Color(0xFFF2F6ED)],
        ).createShader(bounds),
    );
    for (final (x, y, angle, scale) in [
      (-.04, .15, -.55, 1.0),
      (.94, .05, .65, .8),
      (.96, .88, 2.5, 1.2),
    ]) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(angle);
      canvas.scale(scale * size.width / 390);
      final leaf = Path()
        ..moveTo(0, 0)
        ..cubicTo(-64, -82, -18, -145, 0, -156)
        ..cubicTo(52, -116, 64, -36, 0, 0);
      canvas.drawPath(
        leaf,
        Paint()..color = Garden.mint.withValues(alpha: .58),
      );
      canvas.drawLine(
        Offset.zero,
        const Offset(0, -132),
        Paint()
          ..color = Garden.green.withValues(alpha: .07)
          ..strokeWidth = 1.2,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SplashBackdropPainter oldDelegate) => false;
}
