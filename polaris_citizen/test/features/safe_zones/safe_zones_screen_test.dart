import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zone.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_api.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_screen.dart';

class _FakeSafeZonesApi implements SafeZonesApi {
  final Future<List<SafeZone>> Function() _handler;

  _FakeSafeZonesApi(this._handler);

  @override
  Future<List<SafeZone>> fetchSafeZones() => _handler();
}

Widget _buildScreen(SafeZonesApi api) {
  return MaterialApp(
    home: Scaffold(body: SafeZonesScreen(api: api)),
  );
}

void main() {
  testWidgets('shows empty-state message', (WidgetTester tester) async {
    final SafeZonesApi api = _FakeSafeZonesApi(() async => <SafeZone>[]);

    await tester.pumpWidget(_buildScreen(api));
    await tester.pumpAndSettle();

    expect(
      find.text('No active safe zones available right now.'),
      findsOneWidget,
    );
  });

  testWidgets('shows error-state with retry', (WidgetTester tester) async {
    final SafeZonesApi api = _FakeSafeZonesApi(() async {
      throw Exception('network');
    });

    await tester.pumpWidget(_buildScreen(api));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load safe zones.'), findsOneWidget);
    expect(find.byKey(const Key('safe-zones-retry')), findsOneWidget);
  });

  testWidgets('shows zone list after successful load', (
    WidgetTester tester,
  ) async {
    final SafeZonesApi api = _FakeSafeZonesApi(() async {
      return <SafeZone>[
        SafeZone(
          zoneId: 'SZ-100',
          lat: 19.076,
          lng: 72.8777,
          radius: 300,
          confidence: 'HIGH',
          active: true,
          source: 'AUTO',
        ),
      ];
    });

    await tester.pumpWidget(_buildScreen(api));
    await tester.pumpAndSettle();

    expect(find.text('Active safe zones: 1'), findsOneWidget);
    expect(find.text('SZ-100'), findsOneWidget);
  });
}
