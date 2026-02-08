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

  String selectedRiskLevel = "WATCH";
  String selectedSeverity = "ADVISORY";

  final List<String> riskLevels = ["SAFE", "WATCH", "WARNING", "IMMINENT"];
  final List<String> severities = ["INFO", "ADVISORY", "ALERT", "EMERGENCY"];

  final String baseUrl = "http://localhost:8000";

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final decisionRes =
          await http.get(Uri.parse("$baseUrl/decision/latest"));
      final historyRes =
          await http.get(Uri.parse("$baseUrl/override/history"));

      setState(() {
        latestDecision = jsonDecode(decisionRes.body);
        overrideHistory = jsonDecode(historyRes.body);
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  bool get isOverrideActive {
    if (latestDecision == null) return false;
    return latestDecision!["decision_mode"] == "MANUAL_OVERRIDE";
  }

  Future<void> submitOverride() async {
    if (reasonController.text.trim().isEmpty) return;

    setState(() => submitting = true);

    await http.post(
      Uri.parse("$baseUrl/override/set"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "risk_level": selectedRiskLevel,
        "alert_severity": selectedSeverity,
        "decision_mode": "MANUAL_OVERRIDE",
        "reason": reasonController.text.trim(),
        "author": "Authority",
      }),
    );

    reasonController.clear();
    await loadAll();
    setState(() => submitting = false);
  }

  Future<void> clearOverride() async {
    setState(() => submitting = true);
    await http.post(Uri.parse("$baseUrl/override/clear"));
    await loadAll();
    setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Authority Control Panel",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (isOverrideActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Text(
                "MANUAL OVERRIDE ACTIVE — AI DECISIONS ARE SUSPENDED",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),

          Card(
            child: ListTile(
              title: const Text("Current System Decision"),
              subtitle: Text(
                "Risk: ${latestDecision?["final_risk_level"]}\n"
                "Severity: ${latestDecision?["final_alert_severity"]}\n"
                "Mode: ${latestDecision?["decision_mode"]}",
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Manual Override Controls",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: selectedRiskLevel,
                    items: riskLevels
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r),
                            ))
                        .toList(),
                    onChanged:
                        isOverrideActive ? null : (v) => setState(() => selectedRiskLevel = v!),
                    decoration: const InputDecoration(
                      labelText: "Risk Level",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: selectedSeverity,
                    items: severities
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged:
                        isOverrideActive ? null : (v) => setState(() => selectedSeverity = v!),
                    decoration: const InputDecoration(
                      labelText: "Alert Severity",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Override Reason",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed:
                        submitting || isOverrideActive ? null : submitOverride,
                    child: const Text("Activate Manual Override"),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (isOverrideActive)
            ElevatedButton.icon(
              onPressed: submitting ? null : clearOverride,
              icon: const Icon(Icons.cancel),
              label: const Text("Clear Manual Override"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),

          const SizedBox(height: 32),

          const Text(
            "Override History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: overrideHistory.length,
            itemBuilder: (context, index) {
              final h = overrideHistory[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(h["reason"] ?? ""),
                  subtitle: Text(
                    "By ${h["author"] ?? "Unknown"}\n${h["timestamp"] ?? ""}",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
