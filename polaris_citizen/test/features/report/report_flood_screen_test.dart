import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polaris_citizen/features/report/report_api.dart';
import 'package:polaris_citizen/features/report/report_flood_screen.dart';

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

void main() {
  Widget buildTestWidget({required CitizenReportApi api}) {
    return MaterialApp(
      home: Scaffold(body: ReportFloodScreen(api: api)),
    );
  }

  testWidgets('shows validation when zone id is missing', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    await tester.pumpWidget(buildTestWidget(api: api));

    await tester.tap(find.byKey(const Key('submit-level-button')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your zone ID.'), findsOneWidget);
    expect(api.lastZoneId, isNull);
  });

  testWidgets('submits water level with entered zone id', (
    WidgetTester tester,
  ) async {
    final _FakeCitizenReportApi api = _FakeCitizenReportApi();
    await tester.pumpWidget(buildTestWidget(api: api));

    await tester.enterText(find.byKey(const Key('zone-id-input')), 'ZN-101');
    await tester.tap(find.byKey(const Key('submit-level-button')));
    await tester.pumpAndSettle();

    expect(api.lastZoneId, 'ZN-101');
    expect(api.lastLevel, 'MEDIUM');
    expect(find.text('Water level report received'), findsOneWidget);
  });
}
