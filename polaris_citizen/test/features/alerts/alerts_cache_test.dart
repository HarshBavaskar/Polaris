import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/alerts/alerts_cache.dart';
import 'package:polaris_citizen/features/alerts/citizen_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saveAlerts/loadAlerts persists cached alerts', () async {
    final SharedPrefsCitizenAlertsCache cache = SharedPrefsCitizenAlertsCache();
    await cache.saveAlerts(<CitizenAlert>[
      CitizenAlert(
        id: 'a1',
        severity: 'WARNING',
        channel: 'FCM',
        message: 'Heavy rainfall watch',
        timestamp: DateTime.utc(2026, 2, 19, 10, 0),
      ),
    ]);

    final List<CitizenAlert> loaded = await cache.loadAlerts();
    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'a1');
    expect(loaded.first.severity, 'WARNING');
    expect(loaded.first.message, 'Heavy rainfall watch');
  });
}
