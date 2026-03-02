import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polaris_citizen/features/report/report_api.dart';
import 'package:polaris_citizen/features/report/report_flood_screen.dart';
import 'package:polaris_citizen/features/report/report_history.dart';
import 'package:polaris_citizen/features/report/report_offline_queue.dart';

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

class _MemoryHistoryStore implements CitizenReportHistoryStore {
  final List<CitizenReportRecord> records = <CitizenReportRecord>[];

  @override
  Future<List<CitizenReportRecord>> listReports() async {
    return List<CitizenReportRecord>.from(records);
  }

  @override
  Future<void> markStatus({
    required String id,
    required CitizenReportStatus status,
    String? note,
  }) async {}

  @override
  Future<void> upsertRecord(CitizenReportRecord record) async {
    records.add(record);
  }
}

void main() {
  Widget buildTestWidget({
    required CitizenReportApi api,
    ReportOfflineQueue? offlineQueue,
    CitizenReportHistoryStore? historyStore,
    CurrentPositionProvider? positionProvider,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ReportFloodScreen(
          api: api,
          offlineQueue: offlineQueue ?? _MemoryOfflineQueue(),
          historyStore: historyStore ?? _MemoryHistoryStore(),
          positionProvider: positionProvider,
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

  testWidgets('shows validation when custom zone id is missing', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    await tester.pumpWidget(buildTestWidget(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('zone-mode-custom')));
    await tester.pumpAndSettle();
    await tapSubmitLevel(tester);

    expect(find.text('Please enter a custom zone ID.'), findsOneWidget);
    expect(api.lastZoneId, isNull);
  });

  testWidgets('submits water level with area + pincode generated zone id', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    await tester.pumpWidget(buildTestWidget(api: api));
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

  testWidgets(
    'submits water level with custom zone id when custom mode is enabled',
    (WidgetTester tester) async {
      final _FakeCitizenReportApi api = _FakeCitizenReportApi();
      await tester.pumpWidget(buildTestWidget(api: api));
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

  testWidgets('supports city switch and clear/manual area entry', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    await tester.pumpWidget(buildTestWidget(api: api));
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

  testWidgets('auto-fills area from GPS and submits generated zone id', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();

    Future<Position> positionProvider() async {
      return Position(
        longitude: 72.8478,
        latitude: 19.0178,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );
    }

    await tester.pumpWidget(
      buildTestWidget(api: api, positionProvider: positionProvider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('area-gps-autofill-button')));
    await tester.pumpAndSettle();

    final TextField localityField = tester.widget<TextField>(
      find.byKey(const Key('area-locality-input')),
    );
    final TextField pincodeField = tester.widget<TextField>(
      find.byKey(const Key('area-pincode-input')),
    );
    expect(localityField.controller?.text, 'Dadar');
    expect(pincodeField.controller?.text, '400014');

    await tapSubmitLevel(tester);
    expect(api.lastZoneId, 'MUMBAI-DADAR-400014');
  });

  testWidgets('queues water level offline and syncs later', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi()
      ..failWithGenericError = true;
    final _MemoryOfflineQueue offlineQueue = _MemoryOfflineQueue();

    await tester.pumpWidget(
      buildTestWidget(api: api, offlineQueue: offlineQueue),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('area-locality-input')),
      'Dadar',
    );
    await tester.enterText(
      find.byKey(const Key('area-pincode-input')),
      '400014',
    );
    await tapSubmitLevel(tester);
    expect(find.textContaining('saved offline'), findsOneWidget);
    expect(offlineQueue.reports.length, 1);

    api.failWithGenericError = false;
    await tester.tap(find.byKey(const Key('sync-pending-levels-button')));
    await tester.pumpAndSettle();

    expect(offlineQueue.reports, isEmpty);
    expect(api.submitWaterLevelCalls, 2);
  });
}
