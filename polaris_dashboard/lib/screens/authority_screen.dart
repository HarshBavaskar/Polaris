import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/api_service.dart';
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
      final decisionRes = await http.get(Uri.parse('$baseUrl/decision/latest'));
      final historyRes = await http.get(Uri.parse('$baseUrl/override/history'));
      final safeZones = await ApiService.fetchSafeZones();
      final manual = safeZones
          .where((z) => z.active && z.source.toUpperCase() == 'MANUAL')
          .toList();

      if (!mounted) return;
      setState(() {
        latestDecision = jsonDecode(decisionRes.body);
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
    if (latestDecision == null) return false;
    return latestDecision!['decision_mode'] == 'MANUAL_OVERRIDE';
  }

  Future<void> submitOverride() async {
    if (reasonController.text.trim().isEmpty) return;
    setState(() => submitting = true);

    await http.post(
      Uri.parse('$baseUrl/override/set'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'risk_level': selectedRiskLevel,
        'alert_severity': selectedSeverity,
        'decision_mode': 'MANUAL_OVERRIDE',
        'reason': reasonController.text.trim(),
        'author': 'Authority',
      }),
    );

    reasonController.clear();
    await loadAll();
    if (!mounted) return;
    setState(() => submitting = false);
  }

  Future<void> clearOverride() async {
    setState(() => submitting = true);
    await http.post(Uri.parse('$baseUrl/override/clear'));
    await loadAll();
    if (!mounted) return;
    setState(() => submitting = false);
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
    final isCompact = MediaQuery.sizeOf(context).width < 1024 || isAndroidUi;

    return ListView(
      padding: EdgeInsets.all(isCompact ? 12 : 24),
      children: [
        Text(
          'Authority Control Panel',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Override controls and manual safety management',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (isOverrideActive)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF87171)),
            ),
            child: const Text(
              'MANUAL OVERRIDE ACTIVE | AI decisions are suspended',
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (isCompact) ...[
          _decisionCard(context),
          const SizedBox(height: 12),
          _controlsCard(context),
          const SizedBox(height: 12),
          _safeZoneCard(context),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _decisionCard(context)),
              const SizedBox(width: 12),
              Expanded(child: _controlsCard(context)),
            ],
          ),
        if (!isCompact) ...[
          const SizedBox(height: 12),
          _safeZoneCard(context),
        ],
        const SizedBox(height: 18),
        if (isOverrideActive)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : clearOverride,
              icon: const Icon(Icons.cancel_rounded),
              label: const Text('Clear Manual Override'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC53030)),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Override History',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...overrideHistory.map((entry) => _historyCard(context, entry)),
      ],
    );
  }

  Widget _decisionCard(BuildContext context) {
    return Card(
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
                Chip(label: Text('Risk: ${latestDecision?['final_risk_level'] ?? '--'}')),
                Chip(label: Text('Severity: ${latestDecision?['final_alert_severity'] ?? '--'}')),
                Chip(label: Text('Mode: ${latestDecision?['decision_mode'] ?? '--'}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Override Controls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedRiskLevel,
              items: riskLevels.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: isOverrideActive ? null : (v) => setState(() => selectedRiskLevel = v!),
              decoration: const InputDecoration(labelText: 'Risk Level'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedSeverity,
              items: severities.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: isOverrideActive ? null : (v) => setState(() => selectedSeverity = v!),
              decoration: const InputDecoration(labelText: 'Alert Severity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Override Reason'),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: submitting || isOverrideActive ? null : submitOverride,
              icon: const Icon(Icons.shield_rounded),
              label: const Text('Activate Manual Override'),
            ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
        title: Text(history['reason']?.toString() ?? ''),
        subtitle: Text(
          'By ${history['author']?.toString() ?? 'Unknown'} | $displayTimestamp',
        ),
      ),
    );
  }

  Widget _safeZoneCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Safe Zone',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: safeZoneLatController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: safeZoneLngController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
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
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: submitting ? null : submitManualSafeZone,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add Manual Safe Zone'),
            ),
            const SizedBox(height: 16),
            Text(
              'Active Manual Safe Zones',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (manualSafeZones.isEmpty)
              Text(
                'No active manual safe zones.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...manualSafeZones.map((zone) {
                final isDisabling = disablingZoneId == zone.zoneId;
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                zone.zoneId.isEmpty ? 'Manual Safe Zone' : zone.zoneId,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text('Lat: ${zone.lat}, Lng: ${zone.lng}'),
                              Text('Radius: ${zone.radius} m'),
                              if ((zone.reason ?? '').isNotEmpty)
                                Text('Reason: ${zone.reason}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: isDisabling ? null : () => disableManualSafeZone(zone.zoneId),
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
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
