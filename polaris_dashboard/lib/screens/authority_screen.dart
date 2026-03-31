import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/auth_http.dart';
import '../core/api_service.dart';
import '../core/models/override_state.dart';
import '../core/models/safe_zone.dart';

class AuthorityScreen extends StatefulWidget {
  const AuthorityScreen({super.key});

  @override
  State<AuthorityScreen> createState() => _AuthorityScreenState();
}

class _AuthorityScreenState extends State<AuthorityScreen> {
  bool loading = true;
  bool submitting = false;

  Map<String, dynamic>? latestDecision;
  OverrideState? activeOverride;
  List<dynamic> overrideHistory = [];
  List<SafeZone> manualSafeZones = [];
  String? disablingZoneId;

  final TextEditingController reasonController = TextEditingController();
  final TextEditingController safeZoneLatController = TextEditingController();
  final TextEditingController safeZoneLngController = TextEditingController();
  final TextEditingController safeZoneRadiusController =
      TextEditingController(text: '300');
  final TextEditingController safeZoneReasonController = TextEditingController();

  String selectedRiskLevel = 'WATCH';
  String selectedSeverity = 'ADVISORY';

  final List<String> riskLevels = ['SAFE', 'WATCH', 'WARNING', 'IMMINENT'];
  final List<String> severities = ['INFO', 'ADVISORY', 'ALERT', 'EMERGENCY'];

  final String baseUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    reasonController.dispose();
    safeZoneLatController.dispose();
    safeZoneLngController.dispose();
    safeZoneRadiusController.dispose();
    safeZoneReasonController.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final decisionRes = await AuthHttp.get(Uri.parse('$baseUrl/decision/latest'));
      final historyRes = await AuthHttp.get(
        Uri.parse('$baseUrl/override/history'),
        authenticated: true,
      );
      final active = await ApiService.fetchActiveOverride();
      final safeZones = await ApiService.fetchSafeZones();
      final manual = safeZones
          .where((z) => z.active && z.source.toUpperCase() == 'MANUAL')
          .toList();

      if (!mounted) return;
      setState(() {
        latestDecision = jsonDecode(decisionRes.body);
        activeOverride = active;
        overrideHistory = jsonDecode(historyRes.body);
        manualSafeZones = manual;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  bool get isOverrideActive {
    return activeOverride?.active ?? false;
  }

  Future<void> submitOverride() async {
    if (reasonController.text.trim().isEmpty) return;
    setState(() => submitting = true);

    await AuthHttp.post(
      Uri.parse('$baseUrl/override/set'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'risk_level': selectedRiskLevel,
        'alert_severity': selectedSeverity,
        'decision_mode': 'MANUAL_OVERRIDE',
        'reason': reasonController.text.trim(),
        'author': 'Authority',
      }),
      authenticated: true,
    );

    reasonController.clear();
    await loadAll();
    if (!mounted) return;
    setState(() => submitting = false);
  }

  Future<void> clearOverride() async {
    setState(() => submitting = true);
    try {
      await ApiService.clearOverride();
      await loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual override cleared.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to clear manual override.')),
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Future<void> submitManualSafeZone() async {
    final lat = double.tryParse(safeZoneLatController.text.trim());
    final lng = double.tryParse(safeZoneLngController.text.trim());
    final radius = int.tryParse(safeZoneRadiusController.text.trim()) ?? 300;
    final reason = safeZoneReasonController.text.trim();

    if (lat == null || lng == null || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude, longitude and reason.')),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      await ApiService.addManualSafeZone(
        lat: lat,
        lng: lng,
        radius: radius,
        reason: reason,
        author: 'Authority',
      );

      if (!mounted) return;
      safeZoneLatController.clear();
      safeZoneLngController.clear();
      safeZoneReasonController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual safe zone added successfully.')),
      );
      await loadAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add manual safe zone.')),
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Future<void> disableManualSafeZone(String zoneId) async {
    setState(() => disablingZoneId = zoneId);

    try {
      await ApiService.disableManualSafeZone(zoneId: zoneId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manual safe zone $zoneId disabled.')),
      );
      await loadAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to disable safe zone $zoneId.')),
      );
    } finally {
      if (mounted) {
        setState(() => disablingZoneId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 1024 || isAndroidUi;
    return RefreshIndicator(
      onRefresh: loadAll,
      child: ListView(
        padding: EdgeInsets.all(isCompact ? 12 : 24),
        children: [
          _pageHeader(context, compact: isCompact),
          const SizedBox(height: 12),
          if (isCompact) ...[
            _decisionCard(context),
            const SizedBox(height: 12),
            _controlsCard(context),
            const SizedBox(height: 12),
            _safeZoneCard(context),
            const SizedBox(height: 12),
            _activeSafeZoneCard(context),
            const SizedBox(height: 12),
            _overrideHistoryCard(context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _decisionCard(context),
                      const SizedBox(height: 12),
                      _safeZoneCard(context),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _controlsCard(context),
                      const SizedBox(height: 12),
                      _activeSafeZoneCard(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _overrideHistoryCard(context),
          ],
        ],
      ),
    );
  }

  Widget _pageHeader(BuildContext context, {required bool compact}) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Authority Control Panel',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Override controls and manual safety management',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: loadAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authority Control Panel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Override controls and manual safety management',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: loadAll,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _decisionCard(BuildContext context) {
    final risk = latestDecision?['final_risk_level']?.toString() ?? '--';
    final severity = latestDecision?['final_alert_severity']?.toString() ?? '--';
    final mode = latestDecision?['decision_mode']?.toString() ?? '--';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current System Decision',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _decisionBadge('Risk: $risk', _riskTone(risk)),
                _decisionBadge('Severity: $severity', _severityTone(severity)),
                _decisionBadge(
                  'Mode: $mode',
                  _modeTone(mode, Theme.of(context).colorScheme),
                ),
              ],
            ),
            if ((activeOverride?.reason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                activeOverride?.reason ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controlsCard(BuildContext context) {
    final statusTone = isOverrideActive
        ? const Color(0xFFC53030)
        : const Color(0xFF2F855A);
    final activeReason = (activeOverride?.reason ?? '').trim();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Override Controls',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _decisionBadge(
                  isOverrideActive ? 'Status: ACTIVE' : 'Status: INACTIVE',
                  statusTone,
                ),
                _decisionBadge(
                  'Risk: ${activeOverride?.riskLevel ?? selectedRiskLevel}',
                  _riskTone(activeOverride?.riskLevel ?? selectedRiskLevel),
                ),
                _decisionBadge(
                  'Severity: ${activeOverride?.alertSeverity ?? selectedSeverity}',
                  _severityTone(activeOverride?.alertSeverity ?? selectedSeverity),
                ),
              ],
            ),
            if (activeReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: $activeReason',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final split = constraints.maxWidth >= 520;
                final riskDropdown = DropdownButtonFormField<String>(
                  initialValue: selectedRiskLevel,
                  items: riskLevels
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: isOverrideActive
                      ? null
                      : (v) => setState(() => selectedRiskLevel = v!),
                  decoration: const InputDecoration(labelText: 'Risk Level'),
                );
                final severityDropdown = DropdownButtonFormField<String>(
                  initialValue: selectedSeverity,
                  items: severities
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: isOverrideActive
                      ? null
                      : (v) => setState(() => selectedSeverity = v!),
                  decoration: const InputDecoration(labelText: 'Alert Severity'),
                );

                if (!split) {
                  return Column(
                    children: [
                      riskDropdown,
                      const SizedBox(height: 12),
                      severityDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: riskDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: severityDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Override Reason'),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 520;
                final activateButton = FilledButton.icon(
                  onPressed: submitting || isOverrideActive
                      ? null
                      : submitOverride,
                  icon: const Icon(Icons.shield_rounded),
                  label: const Text('Activate Manual Override'),
                );
                final clearButton = FilledButton.tonalIcon(
                  onPressed: submitting ? null : clearOverride,
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Clear Manual Override'),
                );

                if (stacked) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: activateButton),
                      if (isOverrideActive) ...[
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: clearButton),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    activateButton,
                    if (isOverrideActive) clearButton,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _overrideHistoryCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Override History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (overrideHistory.isEmpty)
              Text(
                'No manual override activity recorded yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...overrideHistory.map((entry) => _historyCard(context, entry)),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(BuildContext context, dynamic history) {
    final rawTimestamp = history['timestamp']?.toString();
    final parsedLocalTimestamp =
        rawTimestamp == null ? null : DateTime.tryParse(rawTimestamp)?.toLocal();
    final displayTimestamp = parsedLocalTimestamp == null
        ? (rawTimestamp ?? '')
        : '${parsedLocalTimestamp.year.toString().padLeft(4, '0')}-'
              '${parsedLocalTimestamp.month.toString().padLeft(2, '0')}-'
              '${parsedLocalTimestamp.day.toString().padLeft(2, '0')} '
              '${parsedLocalTimestamp.hour.toString().padLeft(2, '0')}:'
              '${parsedLocalTimestamp.minute.toString().padLeft(2, '0')}:'
              '${parsedLocalTimestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.32),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.history_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history['reason']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'By ${history['author']?.toString() ?? 'Unknown'} | $displayTimestamp',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeZoneForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 520;
            final latField = TextField(
              controller: safeZoneLatController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
            );
            final lngField = TextField(
              controller: safeZoneLngController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
            );

            if (!split) {
              return Column(
                children: [
                  latField,
                  const SizedBox(height: 12),
                  lngField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: latField),
                const SizedBox(width: 12),
                Expanded(child: lngField),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: safeZoneRadiusController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Radius (meters)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: safeZoneReasonController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Reason for safe zone'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: submitting ? null : submitManualSafeZone,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Add Manual Safe Zone'),
          ),
        ),
      ],
    );
  }

  Widget _activeSafeZonesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${manualSafeZones.length} active manual zone${manualSafeZones.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (manualSafeZones.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'No active manual safe zones.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
          ...manualSafeZones.map((zone) {
            final isDisabling = disablingZoneId == zone.zoneId;
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.32),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.zoneId.isEmpty ? 'Manual Safe Zone' : zone.zoneId,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('Lat: ${zone.lat}, Lng: ${zone.lng}'),
                        Text('Radius: ${zone.radius} m'),
                        if ((zone.reason ?? '').isNotEmpty)
                          Text('Reason: ${zone.reason}'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: isDisabling
                        ? null
                        : () => disableManualSafeZone(zone.zoneId),
                    icon: isDisabling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.block_rounded),
                    label: const Text('Disable'),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _safeZoneCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Manual Safe Zone',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _safeZoneForm(context),
          ],
        ),
      ),
    );
  }

  Widget _activeSafeZoneCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Manual Safe Zones',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _activeSafeZonesList(context),
          ],
        ),
      ),
    );
  }

  Widget _decisionBadge(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _riskTone(String value) {
    switch (value.toUpperCase()) {
      case 'IMMINENT':
      case 'EMERGENCY':
        return const Color(0xFFC53030);
      case 'WARNING':
      case 'ALERT':
        return const Color(0xFFDD6B20);
      case 'WATCH':
      case 'ADVISORY':
        return const Color(0xFFD69E2E);
      case 'SAFE':
      case 'INFO':
        return const Color(0xFF2F855A);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _severityTone(String value) {
    switch (value.toUpperCase()) {
      case 'EMERGENCY':
        return const Color(0xFFC53030);
      case 'ALERT':
        return const Color(0xFFDD6B20);
      case 'ADVISORY':
        return const Color(0xFFD69E2E);
      case 'INFO':
        return const Color(0xFF2F855A);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _modeTone(String value, ColorScheme colorScheme) {
    if (value.toUpperCase() == 'MANUAL_OVERRIDE') {
      return const Color(0xFFC53030);
    }
    return colorScheme.primary;
  }
}
