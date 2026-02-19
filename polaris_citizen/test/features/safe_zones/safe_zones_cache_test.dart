import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zone.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saveZones and loadZones persist active zones', () async {
    final SharedPrefsSafeZonesCache cache = SharedPrefsSafeZonesCache();
    await cache.saveZones(<SafeZone>[
      SafeZone(
        zoneId: 'SZ-1',
        lat: 19.076,
        lng: 72.8777,
        radius: 300,
        confidence: 'HIGH',
        active: true,
        source: 'AUTO',
        area: 'Dadar',
        pincode: '400014',
        lastVerified: DateTime.utc(2026, 2, 19, 9, 30),
      ),
      SafeZone(
        zoneId: 'SZ-2',
        lat: 19.08,
        lng: 72.88,
        radius: 300,
        confidence: 'LOW',
        active: false,
        source: 'AUTO',
      ),
    ]);

    final List<SafeZone> loaded = await cache.loadZones();

    expect(loaded, hasLength(1));
    expect(loaded.first.zoneId, 'SZ-1');
    expect(loaded.first.area, 'Dadar');
    expect(loaded.first.pincode, '400014');
    expect(loaded.first.lastVerified, isNotNull);
  });
}
