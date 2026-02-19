import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/report/my_reports_screen.dart';
import 'package:polaris_citizen/features/report/report_history.dart';

class _MemoryHistoryStore implements CitizenReportHistoryStore {
  final List<CitizenReportRecord> _records;

  _MemoryHistoryStore(this._records);

  @override
  Future<List<CitizenReportRecord>> listReports() async {
    return List<CitizenReportRecord>.from(_records);
  }

  @override
  Future<void> markStatus({
    required String id,
    required CitizenReportStatus status,
    String? note,
  }) async {}

  @override
  Future<void> upsertRecord(CitizenReportRecord record) async {}
}

void main() {
  testWidgets('shows summary chips and report entries', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final CitizenReportHistoryStore store =
        _MemoryHistoryStore(<CitizenReportRecord>[
          CitizenReportRecord(
            id: 'r1',
            type: CitizenReportType.waterLevel,
            zoneId: 'MUMBAI-DADAR-400014',
            level: 'HIGH',
            status: CitizenReportStatus.synced,
            createdAt: now.subtract(const Duration(minutes: 20)),
            updatedAt: now.subtract(const Duration(minutes: 10)),
          ),
          CitizenReportRecord(
            id: 'r2',
            type: CitizenReportType.floodPhoto,
            zoneId: 'THANE-400601',
            status: CitizenReportStatus.pendingOffline,
            createdAt: now.subtract(const Duration(minutes: 5)),
            updatedAt: now.subtract(const Duration(minutes: 5)),
            note: 'Saved offline, waiting for sync',
          ),
        ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MyReportsScreen(historyStore: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Reports'), findsOneWidget);
    expect(find.text('Synced: 1'), findsOneWidget);
    expect(find.text('Pending: 1'), findsOneWidget);
    expect(find.text('Failed: 0'), findsOneWidget);
    expect(find.textContaining('MUMBAI-DADAR-400014'), findsOneWidget);
    expect(find.textContaining('THANE-400601'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });
}
