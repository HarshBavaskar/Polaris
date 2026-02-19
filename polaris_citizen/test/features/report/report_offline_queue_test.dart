import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/report/report_offline_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores and reads pending water level reports', () async {
    final SharedPrefsReportOfflineQueue queue = SharedPrefsReportOfflineQueue();
    final PendingWaterLevelReport report = PendingWaterLevelReport(
      zoneId: 'MUMBAI-BANDRA-400050',
      level: 'HIGH',
      queuedAt: DateTime.utc(2026, 2, 19, 10, 30),
    );

    await queue.enqueueWaterLevel(report);
    final List<PendingWaterLevelReport> pending = await queue
        .pendingWaterLevels();

    expect(pending, hasLength(1));
    expect(pending.first.zoneId, 'MUMBAI-BANDRA-400050');
    expect(pending.first.level, 'HIGH');
  });

  test('replaceWaterLevels overwrites queue', () async {
    final SharedPrefsReportOfflineQueue queue = SharedPrefsReportOfflineQueue();
    await queue.enqueueWaterLevel(
      PendingWaterLevelReport(
        zoneId: 'Z1',
        level: 'LOW',
        queuedAt: DateTime.utc(2026, 2, 19),
      ),
    );

    await queue.replaceWaterLevels(<PendingWaterLevelReport>[
      PendingWaterLevelReport(
        zoneId: 'Z2',
        level: 'SEVERE',
        queuedAt: DateTime.utc(2026, 2, 19, 11),
      ),
    ]);

    final List<PendingWaterLevelReport> pending = await queue
        .pendingWaterLevels();
    expect(pending, hasLength(1));
    expect(pending.first.zoneId, 'Z2');
    expect(pending.first.level, 'SEVERE');
  });
}
