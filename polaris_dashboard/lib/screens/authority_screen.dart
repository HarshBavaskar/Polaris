import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  final TextEditingController reasonController = TextEditingController();

  String selectedRiskLevel = 'WATCH';
  String selectedSeverity = 'ADVISORY';

  final List<String> riskLevels = ['SAFE', 'WATCH', 'WARNING', 'IMMINENT'];
  final List<String> severities = ['INFO', 'ADVISORY', 'ALERT', 'EMERGENCY'];

  final String baseUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final decisionRes = await http.get(Uri.parse('$baseUrl/decision/latest'));
      final historyRes = await http.get(Uri.parse('$baseUrl/override/history'));

      if (!mounted) return;
      setState(() {
        latestDecision = jsonDecode(decisionRes.body);
        overrideHistory = jsonDecode(historyRes.body);
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCompact = MediaQuery.sizeOf(context).width < 1024;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Authority Control Panel',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _decisionCard(context)),
              const SizedBox(width: 12),
              Expanded(child: _controlsCard(context)),
            ],
          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
        title: Text(history['reason']?.toString() ?? ''),
        subtitle: Text(
          'By ${history['author']?.toString() ?? 'Unknown'} | ${history['timestamp']?.toString() ?? ''}',
        ),
      ),
    );
  }
}
