import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/report/report_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('upsertRecord and listReports persist records', () async {
    final SharedPrefsCitizenReportHistoryStore store =
        SharedPrefsCitizenReportHistoryStore();
    final DateTime now = DateTime.utc(2026, 2, 19, 10, 0);
    await store.upsertRecord(
      CitizenReportRecord(
        id: 'wl-1',
        type: CitizenReportType.waterLevel,
        zoneId: 'MUMBAI-DADAR-400014',
        level: 'HIGH',
        status: CitizenReportStatus.pendingOffline,
        createdAt: now,
        updatedAt: now,
        note: 'Saved offline',
      ),
    );

    final List<CitizenReportRecord> reports = await store.listReports();
    expect(reports, hasLength(1));
    expect(reports.first.id, 'wl-1');
    expect(reports.first.status, CitizenReportStatus.pendingOffline);
  });

  test('markStatus updates existing report status', () async {
    final SharedPrefsCitizenReportHistoryStore store =
        SharedPrefsCitizenReportHistoryStore();
    final DateTime now = DateTime.utc(2026, 2, 19, 10, 0);
    await store.upsertRecord(
      CitizenReportRecord(
        id: 'wl-2',
        type: CitizenReportType.waterLevel,
        zoneId: 'MUMBAI-KURLA-400070',
        level: 'MEDIUM',
        status: CitizenReportStatus.pendingOffline,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await store.markStatus(
      id: 'wl-2',
      status: CitizenReportStatus.synced,
      note: 'Synced from offline queue',
    );

    final List<CitizenReportRecord> reports = await store.listReports();
    expect(reports.single.status, CitizenReportStatus.synced);
    expect(reports.single.note, 'Synced from offline queue');
  });
}
