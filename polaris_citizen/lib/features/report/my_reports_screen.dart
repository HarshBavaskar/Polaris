import 'package:flutter/material.dart';
import '../../core/settings/citizen_preferences_scope.dart';
import '../../core/settings/citizen_strings.dart';
import '../../widgets/slide_option_selector.dart';
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
  String _filter = 'all';

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

  IconData _typeIcon(CitizenReportType type) {
    switch (type) {
      case CitizenReportType.waterLevel:
        return Icons.water_rounded;
      case CitizenReportType.floodPhoto:
        return Icons.photo_camera_rounded;
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

  IconData _statusIcon(CitizenReportStatus status) {
    switch (status) {
      case CitizenReportStatus.synced:
        return Icons.check_circle_rounded;
      case CitizenReportStatus.pendingOffline:
        return Icons.schedule_rounded;
      case CitizenReportStatus.failed:
        return Icons.error_rounded;
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
    final ColorScheme colors = Theme.of(context).colorScheme;

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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('my-reports-retry-button'),
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(CitizenStrings.tr('retry', languageCode)),
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
    final List<CitizenReportRecord> visibleReports = _reports.where((
      CitizenReportRecord r,
    ) {
      switch (_filter) {
        case 'synced':
          return r.status == CitizenReportStatus.synced;
        case 'pending':
          return r.status == CitizenReportStatus.pendingOffline;
        case 'failed':
          return r.status == CitizenReportStatus.failed;
        default:
          return true;
      }
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          // Header row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long_rounded, size: 28, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _reports.length.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                      ),
                      Text(
                        CitizenStrings.tr('myreports_title', languageCode),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('my-reports-refresh-button'),
                  onPressed: _loading ? null : _loadReports,
                  icon: const Icon(Icons.refresh_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: <Widget>[
              _StatChip(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF2F855A),
                count: syncedCount,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.schedule_rounded,
                color: const Color(0xFFB7791F),
                count: pendingCount,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.error_rounded,
                color: const Color(0xFFC53030),
                count: failedCount,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter
          SlideOptionSelector<String>(
            options: const <String>['all', 'synced', 'pending', 'failed'],
            selected: _filter,
            labelBuilder: (String option) {
              switch (option) {
                case 'synced':
                  return CitizenStrings.tr(
                    'myreports_status_synced',
                    languageCode,
                  );
                case 'pending':
                  return CitizenStrings.tr(
                    'myreports_status_pending',
                    languageCode,
                  );
                case 'failed':
                  return CitizenStrings.tr(
                    'myreports_status_failed',
                    languageCode,
                  );
                default:
                  return 'ALL';
              }
            },
            optionColorBuilder: (String option) {
              switch (option) {
                case 'synced':
                  return const Color(0xFF2F855A);
                case 'pending':
                  return const Color(0xFFB7791F);
                case 'failed':
                  return const Color(0xFFC53030);
                default:
                  return Theme.of(context).colorScheme.primary;
              }
            },
            onSelected: (String option) => setState(() => _filter = option),
          ),

          if (visibleReports.isEmpty) ...<Widget>[
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.inbox_rounded,
                    size: 48,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _reports.isEmpty
                        ? CitizenStrings.tr('myreports_empty', languageCode)
                        : 'No reports in this filter.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            ...visibleReports.map((CitizenReportRecord report) {
              final Color statusColor = _statusColor(report.status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _typeIcon(report.type),
                          size: 20,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  _typeLabel(report.type, languageCode),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(_statusIcon(report.status), size: 12, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        _statusLabel(report.status, languageCode),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.zoneId,
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (report.level != null && report.level!.isNotEmpty)
                              Text(
                                report.level!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _updatedAgo(report.createdAt, languageCode),
                              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
