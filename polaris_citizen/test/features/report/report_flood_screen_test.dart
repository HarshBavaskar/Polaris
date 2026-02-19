import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polaris_citizen/features/report/report_api.dart';
import 'package:polaris_citizen/features/report/report_flood_screen.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zone.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_api.dart';

class _FakeCitizenReportApi implements CitizenReportApi {
  String? lastZoneId;
  String? lastLevel;

  @override
  Future<String> submitWaterLevel({
    required String zoneId,
    required String level,
  }) async {
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

void main() {
  Widget buildTestWidget({
    required CitizenReportApi api,
    required SafeZonesApi safeZonesApi,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ReportFloodScreen(api: api, safeZonesApi: safeZonesApi),
      ),
    );
  }

  Future<void> tapSubmitLevel(WidgetTester tester) async {
    final Finder submitButton = find.byKey(const Key('submit-level-button'));
    await tester.ensureVisible(submitButton);
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
        ),
      );
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

    await tester.pumpWidget(buildTestWidget(api: api, safeZonesApi: zonesApi));
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
        buildTestWidget(api: api, safeZonesApi: zonesApi),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('zone-custom-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('zone-id-input')), 'WARD-44');
      await tapSubmitLevel(tester);

      expect(api.lastZoneId, 'WARD-44');
      expect(api.lastLevel, 'MEDIUM');
      expect(find.text('Water level report received'), findsOneWidget);
    },
  );
}
