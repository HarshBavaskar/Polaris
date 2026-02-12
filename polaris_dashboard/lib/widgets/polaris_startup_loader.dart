import 'package:flutter/material.dart';

class PolarisStartupLoader extends StatefulWidget {
  const PolarisStartupLoader({super.key});

  @override
  State<PolarisStartupLoader> createState() => _PolarisStartupLoaderState();
}

class _PolarisStartupLoaderState extends State<PolarisStartupLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dots = List.generate(3, (i) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = (_controller.value + (i * 0.2)) % 1.0;
          final opacity = (0.3 + (0.7 * (1 - (t - 0.5).abs() * 2))).clamp(0.2, 1.0);
          final scale = 0.75 + (0.35 * opacity);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      );
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/Polaris.png',
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dots[0],
            const SizedBox(width: 8),
            dots[1],
            const SizedBox(width: 8),
            dots[2],
          ],
        ),
      ],
    );
  }
}
