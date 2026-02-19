import 'package:flutter/material.dart';
import 'report_history.dart';

class MyReportsScreen extends StatefulWidget {
  final CitizenReportHistoryStore? historyStore;

  const MyReportsScreen({super.key, this.historyStore});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final CitizenReportHistoryStore _historyStore;
  bool _loading = true;
  String? _errorMessage;
  List<CitizenReportRecord> _reports = <CitizenReportRecord>[];

  @override
  void initState() {
    super.initState();
    _historyStore =
        widget.historyStore ?? SharedPrefsCitizenReportHistoryStore();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final List<CitizenReportRecord> data = await _historyStore.listReports();
      if (!mounted) return;
      setState(() => _reports = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load report history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _updatedAgo(DateTime timestamp) {
    final Duration diff = DateTime.now().difference(timestamp);
    if (diff.isNegative || diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String _typeLabel(CitizenReportType type) {
    switch (type) {
      case CitizenReportType.waterLevel:
        return 'Water Level';
      case CitizenReportType.floodPhoto:
        return 'Flood Photo';
    }
  }

  Color _statusColor(CitizenReportStatus status) {
    switch (status) {
      case CitizenReportStatus.synced:
        return const Color(0xFF2F855A);
      case CitizenReportStatus.pendingOffline:
        return const Color(0xFFB7791F);
      case CitizenReportStatus.failed:
        return const Color(0xFFC53030);
    }
  }

  String _statusLabel(CitizenReportStatus status) {
    switch (status) {
      case CitizenReportStatus.synced:
        return 'SYNCED';
      case CitizenReportStatus.pendingOffline:
        return 'PENDING';
      case CitizenReportStatus.failed:
        return 'FAILED';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_errorMessage!),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('my-reports-retry-button'),
                onPressed: _loadReports,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final int syncedCount = _reports
        .where(
          (CitizenReportRecord r) => r.status == CitizenReportStatus.synced,
        )
        .length;
    final int pendingCount = _reports
        .where(
          (CitizenReportRecord r) =>
              r.status == CitizenReportStatus.pendingOffline,
        )
        .length;
    final int failedCount = _reports
        .where(
          (CitizenReportRecord r) => r.status == CitizenReportStatus.failed,
        )
        .length;

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: <Widget>[
          Card(
            child: ListTile(
              title: const Text(
                'My Reports',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${_reports.length} report(s)'),
              trailing: IconButton(
                key: const Key('my-reports-refresh-button'),
                onPressed: _loading ? null : _loadReports,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text('Synced: $syncedCount'),
                    avatar: const Icon(Icons.check_circle, size: 18),
                  ),
                  Chip(
                    label: Text('Pending: $pendingCount'),
                    avatar: const Icon(Icons.schedule, size: 18),
                  ),
                  Chip(
                    label: Text('Failed: $failedCount'),
                    avatar: const Icon(Icons.error, size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (_reports.isEmpty) ...<Widget>[
            const SizedBox(height: 120),
            const Center(child: Text('No report history yet.')),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            ..._reports.map((CitizenReportRecord report) {
              final Color statusColor = _statusColor(report.status);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            _typeLabel(report.type),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _statusLabel(report.status),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Zone: ${report.zoneId}'),
                      if (report.level != null && report.level!.isNotEmpty)
                        Text('Level: ${report.level}'),
                      if (report.note != null && report.note!.isNotEmpty)
                        Text(
                          report.note!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Created ${_updatedAgo(report.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Updated ${_updatedAgo(report.updatedAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
