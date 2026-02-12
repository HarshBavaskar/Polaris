import 'package:flutter/material.dart';

class AnimatedReveal extends StatelessWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    final totalMs = delay.inMilliseconds + duration.inMilliseconds;
    final safeTotalMs = totalMs <= 0 ? 1 : totalMs;
    final delayFactor = delay.inMilliseconds / safeTotalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: safeTotalMs),
      builder: (context, t, child) {
        final raw = t <= delayFactor ? 0.0 : (t - delayFactor) / (1 - delayFactor);
        final eased = Curves.easeOutCubic.transform(raw.clamp(0.0, 1.0));
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
