import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polaris_citizen/features/report/report_api.dart';
import 'package:polaris_citizen/features/report/report_flood_screen.dart';
import 'package:polaris_citizen/features/report/report_offline_queue.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zone.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_api.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_cache.dart';

class _FakeCitizenReportApi implements CitizenReportApi {
  String? lastZoneId;
  String? lastLevel;
  bool failWithGenericError = false;
  int submitWaterLevelCalls = 0;

  @override
  Future<String> submitWaterLevel({
    required String zoneId,
    required String level,
  }) async {
    submitWaterLevelCalls += 1;
    if (failWithGenericError) {
      throw Exception('offline');
    }
    lastZoneId = zoneId;
    lastLevel = level;
    return 'Water level report received';
  }

  @override
  Future<String> submitFloodPhoto({
    required String zoneId,
    required XFile image,
  }) async {
    return 'Citizen image received';
  }
}

class _FakeSafeZonesApi implements SafeZonesApi {
  final List<SafeZone> zones;

  _FakeSafeZonesApi(this.zones);

  @override
  Future<List<SafeZone>> fetchSafeZones() async => zones;
}

class _ThrowingSafeZonesApi implements SafeZonesApi {
  @override
  Future<List<SafeZone>> fetchSafeZones() async {
    throw Exception('network');
  }
}

class _MemoryOfflineQueue implements ReportOfflineQueue {
  final List<PendingWaterLevelReport> reports = <PendingWaterLevelReport>[];

  @override
  Future<void> enqueueWaterLevel(PendingWaterLevelReport report) async {
    reports.add(report);
  }

  @override
  Future<List<PendingWaterLevelReport>> pendingWaterLevels() async {
    return List<PendingWaterLevelReport>.from(reports);
  }

  @override
  Future<void> replaceWaterLevels(List<PendingWaterLevelReport> next) async {
    reports
      ..clear()
      ..addAll(next);
  }
}

class _MemorySafeZonesCache implements SafeZonesCache {
  List<SafeZone> zones = <SafeZone>[];

  @override
  Future<List<SafeZone>> loadZones() async => List<SafeZone>.from(zones);

  @override
  Future<void> saveZones(List<SafeZone> next) async {
    zones = List<SafeZone>.from(next);
  }
}

void main() {
  Widget buildTestWidget({
    required CitizenReportApi api,
    required SafeZonesApi safeZonesApi,
    ReportOfflineQueue? offlineQueue,
    SafeZonesCache? safeZonesCache,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ReportFloodScreen(
          api: api,
          safeZonesApi: safeZonesApi,
          offlineQueue: offlineQueue ?? _MemoryOfflineQueue(),
          safeZonesCache: safeZonesCache ?? _MemorySafeZonesCache(),
        ),
      ),
    );
  }

  Future<void> tapSubmitLevel(WidgetTester tester) async {
    final Finder submitButton = find.byKey(const Key('submit-level-button'));
    await tester.scrollUntilVisible(
      submitButton,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows validation when no suggested zone and custom id is missing',
    (WidgetTester tester) async {
      final _FakeCitizenReportApi api = _FakeCitizenReportApi();
      await tester.pumpWidget(
        buildTestWidget(
          api: api,
          safeZonesApi: _FakeSafeZonesApi(<SafeZone>[]),
          safeZonesCache: _MemorySafeZonesCache(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('zone-mode-custom')));
      await tester.pumpAndSettle();

      await tapSubmitLevel(tester);

      expect(
        find.text('Please select a zone or enter a custom zone ID.'),
        findsOneWidget,
      );
      expect(api.lastZoneId, isNull);
    },
  );

  testWidgets('submits water level using suggested zone id by default', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    final _FakeSafeZonesApi zonesApi = _FakeSafeZonesApi(<SafeZone>[
      SafeZone(
        zoneId: 'SZ-100',
        lat: 19.076,
        lng: 72.8777,
        radius: 300,
        confidence: 'HIGH',
        active: true,
        source: 'AUTO',
      ),
    ]);

    await tester.pumpWidget(
      buildTestWidget(
        api: api,
        safeZonesApi: zonesApi,
        safeZonesCache: _MemorySafeZonesCache(),
      ),
    );
    await tester.pumpAndSettle();

    await tapSubmitLevel(tester);

    expect(api.lastZoneId, 'SZ-100');
    expect(api.lastLevel, 'MEDIUM');
    expect(find.text('Water level report received'), findsOneWidget);
  });

  testWidgets(
    'submits water level with custom zone id when override is enabled',
    (WidgetTester tester) async {
      final _FakeCitizenReportApi api = _FakeCitizenReportApi();
      final _FakeSafeZonesApi zonesApi = _FakeSafeZonesApi(<SafeZone>[
        SafeZone(
          zoneId: 'SZ-100',
          lat: 19.076,
          lng: 72.8777,
          radius: 300,
          confidence: 'HIGH',
          active: true,
          source: 'AUTO',
        ),
      ]);

      await tester.pumpWidget(
        buildTestWidget(
          api: api,
          safeZonesApi: zonesApi,
          safeZonesCache: _MemorySafeZonesCache(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('zone-mode-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom-zone-id-input')),
        'WARD-44',
      );
      await tapSubmitLevel(tester);

      expect(api.lastZoneId, 'WARD-44');
      expect(api.lastLevel, 'MEDIUM');
      expect(find.text('Water level report received'), findsOneWidget);
    },
  );

  testWidgets('submits water level with area + pincode generated zone id', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    final _FakeSafeZonesApi zonesApi = _FakeSafeZonesApi(<SafeZone>[
      SafeZone(
        zoneId: 'SZ-100',
        lat: 19.076,
        lng: 72.8777,
        radius: 300,
        confidence: 'HIGH',
        active: true,
        source: 'AUTO',
      ),
    ]);

    await tester.pumpWidget(
      buildTestWidget(
        api: api,
        safeZonesApi: zonesApi,
        safeZonesCache: _MemorySafeZonesCache(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('zone-mode-area-pincode')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('area-locality-input')),
      'Thane West',
    );
    await tester.enterText(
      find.byKey(const Key('area-pincode-input')),
      '400601',
    );
    await tapSubmitLevel(tester);

    expect(api.lastZoneId, 'MUMBAI-THANE_WEST-400601');
    expect(api.lastLevel, 'MEDIUM');
    expect(find.text('Water level report received'), findsOneWidget);
  });

  testWidgets('supports city switch and clear/manual area entry', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    final _FakeSafeZonesApi zonesApi = _FakeSafeZonesApi(<SafeZone>[
      SafeZone(
        zoneId: 'SZ-100',
        lat: 19.076,
        lng: 72.8777,
        radius: 300,
        confidence: 'HIGH',
        active: true,
        source: 'AUTO',
      ),
    ]);

    await tester.pumpWidget(
      buildTestWidget(
        api: api,
        safeZonesApi: zonesApi,
        safeZonesCache: _MemorySafeZonesCache(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('zone-mode-area-pincode')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('area-city-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thane').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('area-suggestion-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thane West').last);
    await tester.pumpAndSettle();

    TextField localityField = tester.widget<TextField>(
      find.byKey(const Key('area-locality-input')),
    );
    expect(localityField.controller?.text, 'Thane West');

    await tester.tap(find.byKey(const Key('area-city-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mumbai').last);
    await tester.pumpAndSettle();

    localityField = tester.widget<TextField>(
      find.byKey(const Key('area-locality-input')),
    );
    expect(localityField.controller?.text, '');

    await tester.tap(find.byKey(const Key('area-clear-selection-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('area-locality-input')),
      'Kasarvadavali',
    );
    await tester.pumpAndSettle();
    localityField = tester.widget<TextField>(
      find.byKey(const Key('area-locality-input')),
    );
    expect(localityField.controller?.text, 'Kasarvadavali');
  });

  testWidgets('queues water level offline and syncs later', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi()
      ..failWithGenericError = true;
    final _FakeSafeZonesApi zonesApi = _FakeSafeZonesApi(<SafeZone>[
      SafeZone(
        zoneId: 'SZ-100',
        lat: 19.076,
        lng: 72.8777,
        radius: 300,
        confidence: 'HIGH',
        active: true,
        source: 'AUTO',
      ),
    ]);
    final _MemoryOfflineQueue offlineQueue = _MemoryOfflineQueue();

    await tester.pumpWidget(
      buildTestWidget(
        api: api,
        safeZonesApi: zonesApi,
        offlineQueue: offlineQueue,
        safeZonesCache: _MemorySafeZonesCache(),
      ),
    );
    await tester.pumpAndSettle();

    await tapSubmitLevel(tester);
    expect(find.textContaining('saved offline'), findsOneWidget);
    expect(offlineQueue.reports.length, 1);

    api.failWithGenericError = false;
    await tester.tap(find.byKey(const Key('sync-pending-levels-button')));
    await tester.pumpAndSettle();

    expect(offlineQueue.reports, isEmpty);
    expect(api.submitWaterLevelCalls, 2);
  });

  testWidgets('uses cached suggested zones when API is offline', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    final SafeZonesApi zonesApi = _ThrowingSafeZonesApi();
    final _MemorySafeZonesCache cache = _MemorySafeZonesCache()
      ..zones = <SafeZone>[
        SafeZone(
          zoneId: 'SZ-CACHED-1',
          lat: 19.1,
          lng: 72.9,
          radius: 300,
          confidence: 'HIGH',
          active: true,
          source: 'CACHE',
        ),
      ];

    await tester.pumpWidget(
      buildTestWidget(api: api, safeZonesApi: zonesApi, safeZonesCache: cache),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Offline mode: showing last saved safe zone suggestions.'),
      findsOneWidget,
    );
    expect(find.text('SZ-CACHED-1'), findsOneWidget);
  });
}
