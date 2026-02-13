import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/backend_launcher.dart';
import '../core/refresh_config.dart';
import '../core/theme_controller.dart';
import '../firebase_options.dart';
import '../widgets/animated_reveal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Timer? _statsTimer;
  bool _isRefreshingStats = false;
  bool _isRefreshingMl = false;
  bool _loading = true;
  bool _backendHealthy = false;
  bool _startingBackend = false;
  bool _stoppingBackend = false;
  bool _showBackendTerminal = false;
  bool _mlActionLoading = false;
  bool _mlConfigSaving = false;
  bool _autoTrainingEnabled = true;
  int _autoTrainingThreshold = 50;
  String? _error;
  String? _mlError;
  bool _fetchingWebFcmToken = false;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _mlStatus;

  // VERSION EDIT POINT: update this value when the ongoing version changes.
  static const String _latestOngoingVersion = 'v0.7';

  @override
  void initState() {
    super.initState();
    _refreshAllSettingsData();
    _statsTimer = Timer.periodic(
      RefreshConfig.settingsPoll,
      (_) => _refreshAllSettingsData(silent: true),
    );
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAllSettingsData({bool silent = false}) async {
    await Future.wait([
      _loadStats(silent: silent),
      _loadMlAdminStatus(silent: silent),
    ]);
  }

  Future<void> _loadStats({bool silent = false}) async {
    if (_isRefreshingStats) return;
    _isRefreshingStats = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final base = ApiConfig.baseUrl;
      final backendHealthy = await _checkBackendHealth(base);
      if (!backendHealthy) {
        if (!mounted) return;
        setState(() {
          _backendHealthy = false;
          _error = 'Backend stats unavailable';
          _stats = {
            'backend_health': 'DOWN',
            'risk_level': '--',
            'risk_score': '--',
            'decision_mode': '--',
            'active_risk_points': '--',
            'alerts_count': '--',
            'pending_citizen': '--',
            'backend_online': 'NO',
          };
        });
        return;
      }

      final responses = await Future.wait([
        http.get(Uri.parse('$base/dashboard/current-status')),
        http.get(Uri.parse('$base/decision/latest')),
        http.get(Uri.parse('$base/map/live-risk?limit=50')),
        http.get(Uri.parse('$base/alerts/history?limit=50')),
        http.get(Uri.parse('$base/input/citizen/pending')),
      ]);

      final currentStatusRes = responses[0];
      final decisionRes = responses[1];
      final liveRiskRes = responses[2];
      final alertsRes = responses[3];
      final pendingCitizenRes = responses[4];

      if (currentStatusRes.statusCode != 200 ||
          decisionRes.statusCode != 200 ||
          liveRiskRes.statusCode != 200 ||
          alertsRes.statusCode != 200 ||
          pendingCitizenRes.statusCode != 200) {
        throw Exception('Unable to fetch backend stats');
      }

      final currentStatus =
          jsonDecode(currentStatusRes.body) as Map<String, dynamic>;
      final decision = jsonDecode(decisionRes.body) as Map<String, dynamic>;
      final liveRiskJson = jsonDecode(liveRiskRes.body);
      final alertsJson = jsonDecode(alertsRes.body);
      final pendingCitizen =
          jsonDecode(pendingCitizenRes.body) as List<dynamic>;
      final liveRisk = liveRiskJson is List ? liveRiskJson : <dynamic>[];
      final alerts = alertsJson is List ? alertsJson : <dynamic>[];
      final activeRiskPoints = _countActiveLocations(liveRisk);

      setState(() {
        _backendHealthy = true;
        _error = null;
        _stats = {
          'backend_health': 'UP',
          'risk_level': currentStatus['risk_level']?.toString() ?? '--',
          'risk_score': currentStatus['risk_score']?.toString() ?? '--',
          'decision_mode':
              decision['decision_mode']?.toString() ?? 'AI_DECISION',
          'active_risk_points': activeRiskPoints.toString(),
          'alerts_count': alerts.length.toString(),
          'pending_citizen': pendingCitizen.length.toString(),
          'backend_online': 'YES',
        };
      });
    } catch (_) {
      setState(() {
        _backendHealthy = false;
        _error = 'Backend stats unavailable';
        _stats = {
          'backend_health': 'DOWN',
          'risk_level': '--',
          'risk_score': '--',
          'decision_mode': '--',
          'active_risk_points': '--',
          'alerts_count': '--',
          'pending_citizen': '--',
          'backend_online': 'NO',
        };
      });
    } finally {
      if (mounted) {
        if (!silent) {
          setState(() => _loading = false);
        }
      }
      _isRefreshingStats = false;
    }
  }

  Future<void> _loadMlAdminStatus({bool silent = false}) async {
    if (_isRefreshingMl) return;
    _isRefreshingMl = true;

    try {
      final base = ApiConfig.baseUrl;
      final responses = await Future.wait([
        http.get(Uri.parse('$base/admin/ml/status')),
        http.get(Uri.parse('$base/admin/ml/auto-config')),
      ]);

      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw Exception('Unable to fetch ML admin status');
      }

      final status = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final config = jsonDecode(responses[1].body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _mlStatus = status;
        _autoTrainingEnabled = config['enabled'] == true;
        final thresholdRaw = config['threshold'];
        _autoTrainingThreshold = thresholdRaw is num
            ? thresholdRaw.toInt()
            : _autoTrainingThreshold;
        _mlError = null;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _mlError = 'ML admin controls unavailable';
      });
    } finally {
      _isRefreshingMl = false;
    }
  }

  Future<void> _startMlTraining() async {
    if (_mlActionLoading ||
        _startingBackend ||
        _stoppingBackend ||
        !_backendHealthy) {
      return;
    }
    setState(() => _mlActionLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/ml/retrain-and-reload'),
      );
      final body = jsonDecode(response.body);
      if (!mounted) return;
      final message = body is Map<String, dynamic>
          ? (body['message']?.toString() ?? 'Training request submitted')
          : 'Training request submitted';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadMlAdminStatus(silent: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to trigger ML training job')),
      );
    } finally {
      if (mounted) {
        setState(() => _mlActionLoading = false);
      }
    }
  }

  Future<void> _saveAutoTrainingConfig({
    required bool enabled,
    required int threshold,
  }) async {
    if (_mlConfigSaving) return;
    setState(() => _mlConfigSaving = true);
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/admin/ml/auto-config?enabled=$enabled&threshold=$threshold',
      );
      final response = await http.post(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to update auto training config');
      }
      if (!mounted) return;
      setState(() {
        _autoTrainingEnabled = enabled;
        _autoTrainingThreshold = threshold;
        _mlError = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update auto-training settings'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _mlConfigSaving = false);
      }
    }
  }

  Future<bool> _checkBackendHealth(String base) async {
    try {
      final response = await http
          .get(Uri.parse('$base/backend/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data['up'] == true;
        }
      }
      if (response.statusCode == 404) {
        final root = await http
            .get(Uri.parse('$base/'))
            .timeout(const Duration(seconds: 2));
        return root.statusCode == 200;
      }
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startBackend() async {
    if (_backendHealthy ||
        _startingBackend ||
        _stoppingBackend ||
        !backendLauncherSupported) {
      return;
    }
    setState(() => _startingBackend = true);
    try {
      await startBackendLauncher(showTerminal: _showBackendTerminal);
      final base = ApiConfig.baseUrl;

      var isUp = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 750));
        isUp = await _checkBackendHealth(base);
        if (isUp) break;
      }

      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUp
                ? 'Backend started successfully.'
                : 'Backend launch triggered. It may still be starting...',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start backend. Check start-polaris.ps1.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _startingBackend = false);
      }
    }
  }

  Future<void> _stopBackend() async {
    if (!_backendHealthy ||
        _startingBackend ||
        _stoppingBackend ||
        !backendLauncherSupported) {
      return;
    }
    setState(() => _stoppingBackend = true);
    try {
      await stopBackendLauncher();
      final base = ApiConfig.baseUrl;

      var isStillUp = true;
      for (int i = 0; i < 16; i++) {
        await Future.delayed(const Duration(milliseconds: 600));
        isStillUp = await _checkBackendHealth(base);
        if (!isStillUp) break;
      }

      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isStillUp
                ? 'Stop signal sent. Backend may take a moment to shut down.'
                : 'Backend stopped successfully.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to stop backend server.')),
      );
    } finally {
      if (mounted) {
        setState(() => _stoppingBackend = false);
      }
    }
  }

  Future<void> _showWebFcmTokenDialog() async {
    if (_fetchingWebFcmToken) return;

    if (!kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Web FCM token is available only in the web build.'),
        ),
      );
      return;
    }

    setState(() => _fetchingWebFcmToken = true);

    String? token;
    String? error;
    try {
      final vapidKey = DefaultFirebaseOptions.webVapidKey.trim();
      if (vapidKey.isEmpty || vapidKey.startsWith('REPLACE_')) {
        error =
            'Set webVapidKey in firebase_options.dart before requesting token.';
      } else {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        token = await messaging.getToken(vapidKey: vapidKey);
        if (token == null || token.isEmpty) {
          error =
              'Token not available yet. Refresh and allow notifications in browser settings.';
        }
      }
    } catch (e) {
      error = 'Failed to fetch token: $e';
    } finally {
      if (mounted) {
        setState(() => _fetchingWebFcmToken = false);
      }
    }

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final tokenValue = token!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Web FCM Token'),
          content: SelectableText(tokenValue),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: tokenValue));
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('FCM token copied'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeController = context.watch<ThemeController>();

    final stats = _stats;

    final mlRunning = _mlStatus?['is_running'] == true;
    final mlJob = _mlStatus?['job'] as Map<String, dynamic>?;
    final mlStep =
        mlJob?['step']?.toString() ?? (mlRunning ? 'running' : 'idle');
    final mlLastStatus = mlJob?['status']?.toString() ?? '--';

    return RefreshIndicator(
      onRefresh: _refreshAllSettingsData,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          AnimatedReveal(
            delay: const Duration(milliseconds: 40),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Application',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Version', value: _latestOngoingVersion),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show Backend Terminal'),
                      subtitle: Text(
                        _showBackendTerminal
                            ? 'Backend starts with a visible terminal window'
                            : 'Backend starts hidden in background',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      value: _showBackendTerminal,
                      onChanged: (_startingBackend || _stoppingBackend)
                          ? null
                          : (v) => setState(() => _showBackendTerminal = v),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Backend Server'),
                      subtitle: Text(
                        !backendLauncherSupported
                            ? 'Backend launcher supported on desktop only'
                            : _startingBackend
                            ? 'Starting backend...'
                            : _stoppingBackend
                            ? 'Stopping backend...'
                            : (_backendHealthy
                                  ? 'Running (toggle off to stop)'
                                  : 'Stopped (toggle on to start)'),
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      value: _backendHealthy,
                      onChanged:
                          (_startingBackend ||
                              _stoppingBackend ||
                              !backendLauncherSupported)
                          ? null
                          : (enabled) {
                              if (enabled) {
                                _startBackend();
                              } else {
                                _stopBackend();
                              }
                            },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark mode'),
                      subtitle: Text(
                        themeController.isDarkMode ? 'Enabled' : 'Disabled',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      value: themeController.isDarkMode,
                      onChanged: themeController.setDarkMode,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _fetchingWebFcmToken
                            ? null
                            : _showWebFcmTokenDialog,
                        icon: _fetchingWebFcmToken
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.notifications_active_rounded),
                        label: Text(
                          _fetchingWebFcmToken
                              ? 'Fetching Web FCM Token...'
                              : 'Show/Copy Web FCM Token',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delay: const Duration(milliseconds: 100),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ML Training',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mlRunning
                                ? 'Training in progress: $mlStep'
                                : 'Last job: $mlLastStatus',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed:
                              (_mlActionLoading ||
                                  mlRunning ||
                                  !_backendHealthy)
                              ? null
                              : _startMlTraining,
                          icon: _mlActionLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.model_training_rounded),
                          label: const Text('Train Now'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatic Training'),
                      subtitle: Text(
                        'Starts retraining once feedback reaches the threshold',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      value: _autoTrainingEnabled,
                      onChanged: _mlConfigSaving
                          ? null
                          : (v) => _saveAutoTrainingConfig(
                              enabled: v,
                              threshold: _autoTrainingThreshold,
                            ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Threshold',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _autoTrainingThreshold,
                          items: const [20, 50, 100, 200]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v feedback labels'),
                                ),
                              )
                              .toList(),
                          onChanged: (_mlConfigSaving || !_autoTrainingEnabled)
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  _saveAutoTrainingConfig(
                                    enabled: _autoTrainingEnabled,
                                    threshold: value,
                                  );
                                },
                        ),
                      ],
                    ),
                    if (_mlError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _mlError!,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delay: const Duration(milliseconds: 140),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Backend Stats (Dashboard)',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: _loading ? null : _loadStats,
                          tooltip: 'Refresh backend stats',
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    if (stats != null) ...[
                      const SizedBox(height: 8),
                      _StatGrid(
                        items: [
                          _StatItem('Backend Health', stats['backend_health']!),
                          _StatItem('Backend Online', stats['backend_online']!),
                          _StatItem('Current Risk Level', stats['risk_level']!),
                          _StatItem('Current Risk Score', stats['risk_score']!),
                          _StatItem('Decision Mode', stats['decision_mode']!),
                          _StatItem(
                            'Active Risk Points',
                            stats['active_risk_points']!,
                          ),
                          _StatItem('Alert Records', stats['alerts_count']!),
                          _StatItem(
                            'Pending Citizen Reports',
                            stats['pending_citizen']!,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _countActiveLocations(List<dynamic> points) {
    final activeByLocation = <String, bool>{};

    for (final point in points) {
      if (point is! Map<String, dynamic>) continue;

      final lat = point['lat'];
      final lng = point['lng'];
      if (lat == null || lng == null) continue;

      final key = '$lat,$lng';
      final level = point['risk_level']?.toString().toUpperCase() ?? 'SAFE';
      final isActive = level != 'SAFE';

      activeByLocation[key] = (activeByLocation[key] ?? false) || isActive;
    }

    return activeByLocation.values.where((isActive) => isActive).length;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(items.length, (index) {
        return SizedBox(
          width: 245,
          child: AnimatedReveal(
            delay: Duration(milliseconds: 140 + (index * 35)),
            child: _StatCard(item: items[index]),
          ),
        );
      }),
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value);

  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final healthDown =
        item.label == 'Backend Health' && item.value.toUpperCase() == 'DOWN';
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: healthDown ? const Color(0xFFC53030) : null,
            ),
          ),
        ],
      ),
    );

    if (!healthDown) return card;
    return _UrgencyPulse(color: const Color(0xFFC53030), child: card);
  }
}

class _UrgencyPulse extends StatefulWidget {
  const _UrgencyPulse({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_UrgencyPulse> createState() => _UrgencyPulseState();
}

class _UrgencyPulseState extends State<_UrgencyPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alpha = 0.10 + (_controller.value * 0.2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: alpha),
                blurRadius: 18,
                spreadRadius: 0.4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
