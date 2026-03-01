import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/core/settings/citizen_preferences.dart';
import 'package:polaris_citizen/core/settings/citizen_preferences_scope.dart';
import 'package:polaris_citizen/features/alerts/alerts_api.dart';
import 'package:polaris_citizen/features/alerts/alerts_cache.dart';
import 'package:polaris_citizen/features/alerts/alerts_screen.dart';
import 'package:polaris_citizen/features/alerts/citizen_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAlertsApi implements CitizenAlertsApi {
  final Future<List<CitizenAlert>> Function() _handler;

  _FakeAlertsApi(this._handler);

  @override
  Future<List<CitizenAlert>> fetchAlerts({int limit = 30}) => _handler();
}

class _MemoryAlertsCache implements CitizenAlertsCache {
  List<CitizenAlert> alerts = <CitizenAlert>[];

  @override
  Future<List<CitizenAlert>> loadAlerts() async {
    return List<CitizenAlert>.from(alerts);
  }

  @override
  Future<void> saveAlerts(List<CitizenAlert> value) async {
    alerts = List<CitizenAlert>.from(value);
  }
}

Widget _buildScreen(CitizenAlertsApi api, CitizenAlertsCache cache) {
  return MaterialApp(
    home: Scaffold(
      body: AlertsScreen(api: api, cache: cache),
    ),
  );
}

Widget _buildScreenWithPreferences({
  required CitizenAlertsApi api,
  required CitizenAlertsCache cache,
  required CitizenPreferencesController preferences,
}) {
  return MaterialApp(
    home: CitizenPreferencesScope(
      controller: preferences,
      child: Scaffold(
        body: AlertsScreen(api: api, cache: cache),
      ),
    ),
  );
}

Future<CitizenPreferencesController> _loadPreferences({
  required bool dataSaverEnabled,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'citizen.pref.data_saver.v1': dataSaverEnabled,
  });
  final CitizenPreferencesController controller =
      CitizenPreferencesController();
  await controller.load();
  return controller;
}

void main() {
  testWidgets('shows empty-state when no alerts', (WidgetTester tester) async {
    final CitizenAlertsApi api = _FakeAlertsApi(() async => <CitizenAlert>[]);
    final _MemoryAlertsCache cache = _MemoryAlertsCache();

    await tester.pumpWidget(_buildScreen(api, cache));
    await tester.pumpAndSettle();

    expect(find.text('No alerts available right now.'), findsOneWidget);
  });

  testWidgets('shows alerts list on successful load', (
    WidgetTester tester,
  ) async {
    final CitizenAlertsApi api = _FakeAlertsApi(() async {
      return <CitizenAlert>[
        CitizenAlert(
          id: 'a1',
          severity: 'ALERT',
          channel: 'FCM',
          message: 'Flood alert for low-lying roads',
          timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ];
    });
    final _MemoryAlertsCache cache = _MemoryAlertsCache();

    await tester.pumpWidget(_buildScreen(api, cache));
    await tester.pumpAndSettle();

    expect(find.text('Alerts Feed'), findsOneWidget);
    expect(
      find.textContaining('Flood alert for low-lying roads'),
      findsOneWidget,
    );
    expect(find.textContaining('Updated:'), findsOneWidget);
  });

  testWidgets('uses cached alerts when API fails', (WidgetTester tester) async {
    final CitizenAlertsApi api = _FakeAlertsApi(() async {
      throw Exception('network');
    });
    final _MemoryAlertsCache cache = _MemoryAlertsCache()
      ..alerts = <CitizenAlert>[
        CitizenAlert(
          id: 'cached-1',
          severity: 'WARNING',
          channel: 'FCM',
          message: 'Cached warning alert',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

    await tester.pumpWidget(_buildScreen(api, cache));
    await tester.pumpAndSettle();

    expect(
      find.text('Offline mode: showing last saved alerts.'),
      findsOneWidget,
    );
    expect(find.text('Cached warning alert'), findsOneWidget);
  });

  testWidgets('data saver blocks auto-refresh but allows manual refresh', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    final CitizenAlertsApi api = _FakeAlertsApi(() async {
      calls += 1;
      return <CitizenAlert>[
        CitizenAlert(
          id: 'a2',
          severity: 'WARNING',
          channel: 'FCM',
          message: 'Data saver test alert',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      ];
    });
    final _MemoryAlertsCache cache = _MemoryAlertsCache();
    final CitizenPreferencesController preferences = await _loadPreferences(
      dataSaverEnabled: true,
    );

    await tester.pumpWidget(
      _buildScreenWithPreferences(
        api: api,
        cache: cache,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('alerts-refresh-button')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
