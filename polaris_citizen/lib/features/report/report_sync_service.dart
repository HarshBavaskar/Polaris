import 'report_api.dart';
import 'report_history.dart';
import 'report_offline_queue.dart';

class ReportSyncSummary {
  final int synced;
  final int failed;
  final int pending;

  const ReportSyncSummary({
    required this.synced,
    required this.failed,
    required this.pending,
  });
}

class ReportSyncService {
  final CitizenReportApi api;
  final ReportOfflineQueue offlineQueue;
  final CitizenReportHistoryStore historyStore;

  const ReportSyncService({
    required this.api,
    required this.offlineQueue,
    required this.historyStore,
  });

  Future<ReportSyncSummary> syncPendingWaterLevels() async {
    final List<PendingWaterLevelReport> pending = await offlineQueue
        .pendingWaterLevels();
    if (pending.isEmpty) {
      return const ReportSyncSummary(synced: 0, failed: 0, pending: 0);
    }

    int synced = 0;
    int failed = 0;
    final List<PendingWaterLevelReport> remaining =
        <PendingWaterLevelReport>[];
    for (final PendingWaterLevelReport report in pending) {
      try {
        await api.submitWaterLevel(zoneId: report.zoneId, level: report.level);
        synced += 1;
        await historyStore.markStatus(
          id: report.clientReportId,
          status: CitizenReportStatus.synced,
          note: 'Synced from offline queue',
        );
      } on CitizenReportHttpException {
        failed += 1;
        await historyStore.markStatus(
          id: report.clientReportId,
          status: CitizenReportStatus.failed,
          note: 'Sync failed: rejected by server',
        );
      } catch (_) {
        remaining.add(report);
      }
    }

    await offlineQueue.replaceWaterLevels(remaining);
    return ReportSyncSummary(
      synced: synced,
      failed: failed,
      pending: remaining.length,
    );
  }
}
