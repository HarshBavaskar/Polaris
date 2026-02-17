import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/refresh_config.dart';

class TopBar extends StatefulWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.isCompact,
    this.onMenuTap,
  });

  final String title;
  final bool isCompact;
  final VoidCallback? onMenuTap;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late Timer _clockTimer;
  Timer? _eventsTimer;
  DateTime _now = DateTime.now();
  bool _isLoadingEvents = false;

  String _marqueeText = 'Loading authority events...';
  _MarqueeTone _marqueeTone = _MarqueeTone.neutral;

  @override
  void initState() {
    super.initState();
    _loadEventMarquee();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _eventsTimer =
        Timer.periodic(RefreshConfig.topBarEventsPoll, (_) => _loadEventMarquee());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _eventsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEventMarquee() async {
    if (_isLoadingEvents) return;
    _isLoadingEvents = true;

    try {
      final base = ApiConfig.baseUrl;
      final responses = await Future.wait([
        http.get(Uri.parse('$base/alerts/history?limit=20')),
        http.get(Uri.parse('$base/input/citizen/pending')),
      ]);

      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) return;

      final alertsJson = jsonDecode(responses[0].body);
      final pendingReports = jsonDecode(responses[1].body) as List<dynamic>;

      final messages = <String>[];
      var tone = _MarqueeTone.neutral;
      var highestSeverityRank = -1;

      if (pendingReports.isNotEmpty) {
        messages.add('[REVIEW] ${pendingReports.length} citizen report(s) pending authority review');
        tone = _MarqueeTone.review;
      }

      final alerts = alertsJson is List ? alertsJson : <dynamic>[];
      final activeAlerts = alerts.whereType<Map<String, dynamic>>().where(_isActiveAlert).toList();

      for (final alert in activeAlerts.take(4)) {
        final severity = alert['severity']?.toString().toUpperCase() ?? 'INFO';
        final message = alert['message']?.toString() ?? 'Active alert requires review';
        messages.add('[$severity] $message');
        highestSeverityRank = math.max(highestSeverityRank, _severityRank(severity));
      }

      if (highestSeverityRank >= 3) {
        tone = _MarqueeTone.emergency;
      } else if (highestSeverityRank >= 2) {
        tone = _MarqueeTone.alert;
      } else if (highestSeverityRank >= 1 && tone == _MarqueeTone.neutral) {
        tone = _MarqueeTone.advisory;
      }

      final next = messages.isEmpty
          ? 'No active alerts. System monitoring is active.'
          : messages.join('   |   ');

      if (mounted) {
        setState(() {
          _marqueeText = next;
          _marqueeTone = tone;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _marqueeText = 'Unable to fetch latest events. Check backend connectivity.';
          _marqueeTone = _MarqueeTone.error;
        });
      }
    } finally {
      _isLoadingEvents = false;
    }
  }

  bool _isActiveAlert(Map<String, dynamic> alert) {
    final status = alert['status']?.toString().toUpperCase();
    final severity = alert['severity']?.toString().toUpperCase() ?? 'INFO';
    if (status != null && {'QUEUED', 'ACTIVE', 'IN_PROGRESS'}.contains(status)) return true;
    return {'EMERGENCY', 'ALERT', 'WARNING', 'WATCH', 'ADVISORY'}.contains(severity);
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'EMERGENCY':
        return 3;
      case 'ALERT':
        return 2;
      case 'ADVISORY':
        return 1;
      default:
        return 0;
    }
  }

  _MarqueePalette _paletteForTone(_MarqueeTone tone, bool isDark) {
    if (isDark) {
      return switch (tone) {
        _MarqueeTone.emergency => const _MarqueePalette(
            background: Color(0xFF2A0F12),
            border: Color(0xFF7F1D1D),
            text: Color(0xFFFFE4E6),
            accent: Color(0xFFF87171),
          ),
        _MarqueeTone.alert => const _MarqueePalette(
            background: Color(0xFF2A1B08),
            border: Color(0xFF92400E),
            text: Color(0xFFFFF1DC),
            accent: Color(0xFFFB923C),
          ),
        _MarqueeTone.advisory => const _MarqueePalette(
            background: Color(0xFF262109),
            border: Color(0xFF854D0E),
            text: Color(0xFFFEF9C3),
            accent: Color(0xFFFACC15),
          ),
        _MarqueeTone.review => const _MarqueePalette(
            background: Color(0xFF102436),
            border: Color(0xFF1E3A8A),
            text: Color(0xFFE0F2FE),
            accent: Color(0xFF60A5FA),
          ),
        _MarqueeTone.error => const _MarqueePalette(
            background: Color(0xFF271212),
            border: Color(0xFF7F1D1D),
            text: Color(0xFFFEE2E2),
            accent: Color(0xFFF87171),
          ),
        _MarqueeTone.neutral => const _MarqueePalette(
            background: Color(0xFF16181C),
            border: Color(0xFF3F3F46),
            text: Color(0xFFF5F5F5),
            accent: Color(0xFFA3A3A3),
          ),
      };
    }

    return switch (tone) {
      _MarqueeTone.emergency => const _MarqueePalette(
          background: Color(0xFFFFE4E6),
          border: Color(0xFFFDA4AF),
          text: Color(0xFF7F1D1D),
          accent: Color(0xFFB91C1C),
        ),
      _MarqueeTone.alert => const _MarqueePalette(
          background: Color(0xFFFFF1E6),
          border: Color(0xFFFCC48D),
          text: Color(0xFF7C2D12),
          accent: Color(0xFFC2410C),
        ),
      _MarqueeTone.advisory => const _MarqueePalette(
          background: Color(0xFFFFF9DB),
          border: Color(0xFFFDE68A),
          text: Color(0xFF713F12),
          accent: Color(0xFFA16207),
        ),
      _MarqueeTone.review => const _MarqueePalette(
          background: Color(0xFFE6F2FF),
          border: Color(0xFFB9D8FF),
          text: Color(0xFF1E3A8A),
          accent: Color(0xFF1D4ED8),
        ),
      _MarqueeTone.error => const _MarqueePalette(
          background: Color(0xFFFEE2E2),
          border: Color(0xFFFCA5A5),
          text: Color(0xFF7F1D1D),
          accent: Color(0xFFB91C1C),
        ),
      _MarqueeTone.neutral => const _MarqueePalette(
          background: Color(0xFFF2F7FF),
          border: Color(0xFFD8E3F2),
          text: Color(0xFF1F2937),
          accent: Color(0xFF1A73E8),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final compactUi = widget.isCompact || isAndroidUi;
    final colorScheme = Theme.of(context).colorScheme;

    if (compactUi) {
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onMenuTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onMenuTap,
                    tooltip: 'Open menu',
                    icon: const Icon(Icons.menu_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        height: double.infinity,
                        child: Image.asset(
                          'assets/Polaris_Logo_Side.PNG',
                          fit: BoxFit.fitHeight,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final palette = _paletteForTone(
      _marqueeTone,
      Theme.of(context).brightness == Brightness.dark,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_rounded,
                    color: palette.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SeamlessMarquee(
                      text: _marqueeText,
                      textColor: palette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Chip(
            avatar: const _PulsingStatusDot(),
            label: const Text('System online'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 10),
          Text(
            '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')} Local',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SeamlessMarquee extends StatefulWidget {
  const _SeamlessMarquee({
    required this.text,
    required this.textColor,
  });

  final String text;
  final Color textColor;

  @override
  State<_SeamlessMarquee> createState() => _SeamlessMarqueeState();
}

class _SeamlessMarqueeState extends State<_SeamlessMarquee>
    with SingleTickerProviderStateMixin {
  static const double _gap = 56;
  late final AnimationController _controller;
  int _lastDurationMs = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: RefreshConfig.marqueeMinCycle)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant _SeamlessMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller
        ..stop()
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: widget.textColor,
          fontWeight: FontWeight.w700,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = tp.width;
        final containerWidth = constraints.maxWidth;

        final distance = textWidth + _gap;
        final repeatCount = math.max(2, (containerWidth / distance).ceil() + 2);
        final durationMs = _computeDurationMs(distance);
        if (durationMs != _lastDurationMs) {
          _lastDurationMs = durationMs;
          _controller
            ..duration = Duration(milliseconds: durationMs)
            ..repeat();
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = -(distance * _controller.value);
              return Transform.translate(
                offset: Offset(dx, 0),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(repeatCount * 2 - 1, (index) {
                      if (index.isOdd) return const SizedBox(width: _gap);
                      return Text(widget.text, maxLines: 1, style: style);
                    }),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  int _computeDurationMs(double distance) {
    final seconds = distance / RefreshConfig.marqueePixelsPerSecond;
    final minSeconds = RefreshConfig.marqueeMinCycle.inMilliseconds / 1000;
    final effective = math.max(seconds, minSeconds);
    return (effective * 1000).round();
  }
}

enum _MarqueeTone { neutral, review, advisory, alert, emergency, error }

class _MarqueePalette {
  const _MarqueePalette({
    required this.background,
    required this.border,
    required this.text,
    required this.accent,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color accent;
}

class _PulsingStatusDot extends StatefulWidget {
  const _PulsingStatusDot();

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: const Icon(Icons.circle, size: 10, color: Color(0xFF00C36D)),
    );
  }
}
