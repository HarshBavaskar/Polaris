import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
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

  String _languageCode(BuildContext context) {
    return CitizenPreferencesScope.maybeOf(context)?.languageCode ?? 'en';
  }

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
      final String languageCode = _languageCode(context);
      setState(
        () => _errorMessage = CitizenStrings.tr(
          'myreports_load_failed',
          languageCode,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _updatedAgo(DateTime timestamp, String languageCode) {
    return CitizenStrings.relativeTimeFromNow(timestamp, languageCode);
  }

  String _typeLabel(CitizenReportType type, String languageCode) {
    switch (type) {
      case CitizenReportType.waterLevel:
        return CitizenStrings.tr('myreports_type_water_level', languageCode);
      case CitizenReportType.floodPhoto:
        return CitizenStrings.tr('myreports_type_flood_photo', languageCode);
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

  String _statusLabel(CitizenReportStatus status, String languageCode) {
    switch (status) {
      case CitizenReportStatus.synced:
        return CitizenStrings.tr('myreports_status_synced', languageCode);
      case CitizenReportStatus.pendingOffline:
        return CitizenStrings.tr('myreports_status_pending', languageCode);
      case CitizenReportStatus.failed:
        return CitizenStrings.tr('myreports_status_failed', languageCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = _languageCode(context);
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
                child: Text(CitizenStrings.tr('retry', languageCode)),
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
              title: Text(
                CitizenStrings.tr('myreports_title', languageCode),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                CitizenStrings.trf(
                  'myreports_count',
                  languageCode,
                  <String, String>{'count': _reports.length.toString()},
                ),
              ),
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
                    label: Text(
                      CitizenStrings.trf(
                        'myreports_synced',
                        languageCode,
                        <String, String>{'count': syncedCount.toString()},
                      ),
                    ),
                    avatar: const Icon(Icons.check_circle, size: 18),
                  ),
                  Chip(
                    label: Text(
                      CitizenStrings.trf(
                        'myreports_pending',
                        languageCode,
                        <String, String>{'count': pendingCount.toString()},
                      ),
                    ),
                    avatar: const Icon(Icons.schedule, size: 18),
                  ),
                  Chip(
                    label: Text(
                      CitizenStrings.trf(
                        'myreports_failed',
                        languageCode,
                        <String, String>{'count': failedCount.toString()},
                      ),
                    ),
                    avatar: const Icon(Icons.error, size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (_reports.isEmpty) ...<Widget>[
            const SizedBox(height: 120),
            Center(
              child: Text(CitizenStrings.tr('myreports_empty', languageCode)),
            ),
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
                            _typeLabel(report.type, languageCode),
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
                              _statusLabel(report.status, languageCode),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CitizenStrings.trf(
                          'myreports_zone',
                          languageCode,
                          <String, String>{'zone': report.zoneId},
                        ),
                      ),
                      if (report.level != null && report.level!.isNotEmpty)
                        Text(
                          CitizenStrings.trf(
                            'myreports_level',
                            languageCode,
                            <String, String>{'level': report.level!},
                          ),
                        ),
                      if (report.note != null && report.note!.isNotEmpty)
                        Text(
                          report.note!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        CitizenStrings.trf(
                          'myreports_created',
                          languageCode,
                          <String, String>{
                            'ago': _updatedAgo(report.createdAt, languageCode),
                          },
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        CitizenStrings.trf(
                          'myreports_updated',
                          languageCode,
                          <String, String>{
                            'ago': _updatedAgo(report.updatedAt, languageCode),
                          },
                        ),
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
