import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/api.dart';
import '../core/refresh_config.dart';
import '../core/models/citizen_report.dart';

class CitizenVerificationScreen extends StatefulWidget {
  const CitizenVerificationScreen({super.key});

  @override
  State<CitizenVerificationScreen> createState() =>
      _CitizenVerificationScreenState();
}

class _CitizenVerificationScreenState extends State<CitizenVerificationScreen> {
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool loading = true;
  String? processingReportId;
  List<CitizenReport> pendingReports = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
    _refreshTimer = Timer.periodic(
      RefreshConfig.citizenVerificationPoll,
      (_) => _loadPending(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPending({bool silent = false}) async {
    if (_isRefreshing || processingReportId != null) return;
    _isRefreshing = true;
    if (!silent) {
      setState(() => loading = true);
    }
    try {
      final data = await ApiService.fetchPendingCitizenReports();
      if (!mounted) return;
      setState(() {
        pendingReports = data;
        if (!silent) loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() => loading = false);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _review(CitizenReport report, String action) async {
    setState(() => processingReportId = report.reportId);
    try {
      await ApiService.reviewCitizenReport(
        reportId: report.reportId,
        action: action,
        verifier: "Authority",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report ${report.reportId} $action')),
      );
      await _loadPending();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update report status')),
      );
      setState(() => processingReportId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final compact = MediaQuery.sizeOf(context).width < 900 || isAndroidUi;

    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView(
        padding: EdgeInsets.all(compact ? 12 : 24),
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citizen Verification',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review pending field reports and approve or reject quickly',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loadPending,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Citizen Verification',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loadPending,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            'Review pending field reports and approve or reject quickly',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pending reports: ${pendingReports.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (pendingReports.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No pending citizen reports for verification.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else
            ...pendingReports.map(_reportCard),
        ],
      ),
    );
  }

  Widget _reportCard(CitizenReport report) {
    final isProcessing = processingReportId == report.reportId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.type == "IMAGE"
                  ? 'Citizen Image Report'
                  : 'Citizen Water Level Report',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Report: ${report.reportId}')),
                Chip(label: Text('Zone: ${report.zoneId}')),
                if (report.level != null)
                  Chip(label: Text('Level: ${report.level}')),
                if (report.filename != null)
                  Chip(label: Text('File: ${report.filename}')),
              ],
            ),
            if (report.timestamp != null) ...[
              const SizedBox(height: 8),
              Text(
                'Submitted: ${report.timestamp!.toLocal()}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (report.type == "IMAGE" &&
                (report.filename ?? "").isNotEmpty) ...[
              const SizedBox(height: 10),
              _photoPreview(report),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _review(report, "APPROVE"),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: const Text('Approve'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isProcessing
                      ? null
                      : () => _review(report, "REJECT"),
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPreview(CitizenReport report) {
    final imageUrl =
        '${ApiConfig.baseUrl}/input/citizen/image/${Uri.encodeComponent(report.filename!)}';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openPhotoDialog(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 180),
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Image preview unavailable'),
            ),
          ),
        ),
      ),
    );
  }

  void _openPhotoDialog(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Citizen Photo'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Unable to load image'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
