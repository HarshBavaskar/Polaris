import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  // VERSION EDIT POINT: update this value when the ongoing version changes.
  static const String _latestOngoingVersion = 'v0.7';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final base = ApiConfig.baseUrl;
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

      final currentStatus = jsonDecode(currentStatusRes.body) as Map<String, dynamic>;
      final decision = jsonDecode(decisionRes.body) as Map<String, dynamic>;
      final liveRiskJson = jsonDecode(liveRiskRes.body);
      final alertsJson = jsonDecode(alertsRes.body);
      final pendingCitizen = jsonDecode(pendingCitizenRes.body) as List<dynamic>;
      final liveRisk = liveRiskJson is List ? liveRiskJson : <dynamic>[];
      final alerts = alertsJson is List ? alertsJson : <dynamic>[];
      final activeRiskPoints = _countActiveLocations(liveRisk);

      setState(() {
        _stats = {
          'risk_level': currentStatus['risk_level']?.toString() ?? '--',
          'risk_score': currentStatus['risk_score']?.toString() ?? '--',
          'decision_mode': decision['decision_mode']?.toString() ?? 'AI_DECISION',
          'active_risk_points': activeRiskPoints.toString(),
          'alerts_count': alerts.length.toString(),
          'pending_citizen': pendingCitizen.length.toString(),
          'backend_online': 'YES',
        };
      });
    } catch (_) {
      setState(() {
        _error = 'Backend stats unavailable';
        _stats = {
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
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeController = context.watch<ThemeController>();

    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 20),
          Card(
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
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Version', value: _latestOngoingVersion),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
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
                        _StatItem('Backend Online', stats['backend_online']!),
                        _StatItem('Current Risk Level', stats['risk_level']!),
                        _StatItem('Current Risk Score', stats['risk_score']!),
                        _StatItem('Decision Mode', stats['decision_mode']!),
                        _StatItem('Active Risk Points', stats['active_risk_points']!),
                        _StatItem('Alert Records', stats['alerts_count']!),
                        _StatItem('Pending Citizen Reports', stats['pending_citizen']!),
                      ],
                    ),
                  ],
                ],
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
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
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
      children: items
          .map(
            (item) => SizedBox(
              width: 245,
              child: _StatCard(item: item),
            ),
          )
          .toList(),
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

    return Container(
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
                ),
          ),
        ],
      ),
    );
  }
}
