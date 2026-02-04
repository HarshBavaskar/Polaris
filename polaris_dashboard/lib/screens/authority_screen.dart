import 'package:flutter/material.dart';
import 'package:polaris_dashboard/core/global_reload.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/models/override_state.dart';

class AuthorityScreen extends StatefulWidget {
  const AuthorityScreen({super.key});

  @override
  State<AuthorityScreen> createState() => _AuthorityScreenState();
}

class _AuthorityScreenState extends State<AuthorityScreen> {
  OverrideState? active;
  List<OverrideState> history = [];
  bool loading = true;

  String risk = "WATCH";
  String severity = "ADVISORY";
  final reasonCtrl = TextEditingController();
  final authorCtrl = TextEditingController(text: "Authority");

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
  try {
    final a = await ApiService.fetchActiveOverride();
    final h = await ApiService.fetchOverrideHistory();

    setState(() {
      active = a;
      history = h;
      loading = false;
    });
  } catch (e) {
    setState(() {
      loading = false;
    });
  }
  }


  Future<void> submitOverride() async {
    if (reasonCtrl.text.trim().isEmpty) return;

    await ApiService.setOverride(
      riskLevel: risk,
      alertSeverity: severity,
      reason: reasonCtrl.text,
      author: authorCtrl.text,
    );

    reasonCtrl.clear();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<GlobalReload>();
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ACTIVE OVERRIDE STATUS
          Card(
            color: active != null ? Colors.red.shade50 : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                active != null
                    ? "MANUAL OVERRIDE ACTIVE — ${active!.riskLevel}"
                    : "No manual override active",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SET OVERRIDE
          const Text(
            "Set Manual Override",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              DropdownButton<String>(
                value: risk,
                items: const [
                  DropdownMenuItem(value: "SAFE", child: Text("SAFE")),
                  DropdownMenuItem(value: "WATCH", child: Text("WATCH")),
                  DropdownMenuItem(value: "WARNING", child: Text("WARNING")),
                  DropdownMenuItem(value: "IMMINENT", child: Text("IMMINENT")),
                ],
                onChanged: (v) => setState(() => risk = v!),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: severity,
                items: const [
                  DropdownMenuItem(value: "INFO", child: Text("INFO")),
                  DropdownMenuItem(value: "ADVISORY", child: Text("ADVISORY")),
                  DropdownMenuItem(value: "ALERT", child: Text("ALERT")),
                  DropdownMenuItem(value: "EMERGENCY", child: Text("EMERGENCY")),
                ],
                onChanged: (v) => setState(() => severity = v!),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: "Reason (required)",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: submitOverride,
            child: const Text("Apply Manual Override"),
          ),

          const Divider(height: 40),

          // HISTORY
          const Text(
            "Override History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: history.isEmpty
              ? const Center(child: Text("No override history available."))
              : ListView.builder(
              itemCount: history.length,
              itemBuilder: (_, i) {
              final h = history[i];
              return ListTile(
                title: Text("${h.riskLevel} · ${h.alertSeverity}"),
                subtitle: Text(
                "${h.reason}\n${h.author} · ${h.timestamp.toLocal()}",
                ),
              );
            },
          ),
          ),
        ],
      ),
    );
  }
}
