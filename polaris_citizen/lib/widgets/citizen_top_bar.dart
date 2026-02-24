import 'dart:async';

import 'package:flutter/material.dart';

class CitizenTopBar extends StatefulWidget {
  const CitizenTopBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    required this.onLanguageTap,
    required this.languageTooltip,
  });

  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onLanguageTap;
  final String languageTooltip;

  @override
  State<CitizenTopBar> createState() => _CitizenTopBarState();
}

class _CitizenTopBarState extends State<CitizenTopBar> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bool isAndroidUi = theme.platform == TargetPlatform.android;

    return Container(
      margin: EdgeInsets.fromLTRB(10, isAndroidUi ? 8 : 10, 10, 8),
      padding: EdgeInsets.symmetric(horizontal: isAndroidUi ? 10 : 12, vertical: isAndroidUi ? 10 : 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 360;
                return SizedBox(
                  height: compact ? 62 : 72,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Open navigation menu',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onMenuTap,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            height: compact ? 38 : double.infinity,
                            child: Image.asset(
                              'assets/Polaris_Logo_Side.PNG',
                              fit: BoxFit.fitHeight,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('appbar-go-language'),
                        tooltip: widget.languageTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onLanguageTap,
                        icon: const Icon(Icons.language_outlined),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isAndroidUi ? 8 : 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isAndroidUi ? 12 : 14, vertical: isAndroidUi ? 10 : 12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: <Widget>[
                const _LoadingBars(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBars extends StatefulWidget {
  const _LoadingBars();

  @override
  State<_LoadingBars> createState() => _LoadingBarsState();
}

class _LoadingBarsState extends State<_LoadingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color barColor = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 22,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(3, (int index) {
              final double phase = (_controller.value + (index * 0.18)) % 1.0;
              final double h = 5 + ((1 - (phase - 0.5).abs() * 2) * 7);
              return Container(
                width: 4,
                height: h.clamp(5, 12),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
