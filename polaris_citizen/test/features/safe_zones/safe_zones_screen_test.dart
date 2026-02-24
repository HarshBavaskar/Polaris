import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zone.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_api.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_cache.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_screen.dart';

class _FakeSafeZonesApi implements SafeZonesApi {
  final Future<List<SafeZone>> Function() _handler;

  _FakeSafeZonesApi(this._handler);

  @override
  Future<List<SafeZone>> fetchSafeZones() => _handler();
}

Widget _buildScreen(
  SafeZonesApi api, {
  UserLocationProvider? locationProvider,
  SafeZonesCache? cache,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SafeZonesScreen(
        api: api,
        userLocationProvider: locationProvider,
        cache: cache,
      ),
    ),
  );
}

class _MemorySafeZonesCache implements SafeZonesCache {
  List<SafeZone> zones = <SafeZone>[];
  DateTime? updatedAt;

  @override
  Future<List<SafeZone>> loadZones() async => List<SafeZone>.from(zones);

  @override
  Future<void> saveZones(List<SafeZone> next) async {
    zones = List<SafeZone>.from(next);
    updatedAt = DateTime.now();
  }

  @override
  Future<DateTime?> lastUpdatedAt() async {
    return updatedAt;
  }
}

void main() {
  testWidgets('shows empty-state message', (WidgetTester tester) async {
    final SafeZonesApi api = _FakeSafeZonesApi(() async => <SafeZone>[]);
    final _MemorySafeZonesCache cache = _MemorySafeZonesCache();

    await tester.pumpWidget(_buildScreen(api, cache: cache));
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
    final _MemorySafeZonesCache cache = _MemorySafeZonesCache();

    await tester.pumpWidget(_buildScreen(api, cache: cache));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safe-zones-unavailable-card')), findsOneWidget);
    expect(
      find.text('Safe zones are temporarily unavailable.'),
      findsOneWidget,
    );
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
          area: 'Dadar',
          pincode: '400014',
          lastVerified: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];
    });
    final _MemorySafeZonesCache cache = _MemorySafeZonesCache();

    await tester.pumpWidget(_buildScreen(api, cache: cache));
    await tester.pumpAndSettle();

    expect(find.text('Active safe zones: 1'), findsOneWidget);
    expect(find.text('SZ-100'), findsOneWidget);
    expect(find.textContaining('Area: Dadar'), findsOneWidget);
    expect(find.textContaining('Pincode: 400014'), findsOneWidget);
    expect(find.textContaining('Updated:'), findsOneWidget);
  });

  testWidgets('shows distance when location is enabled', (
    WidgetTester tester,
  ) async {
    final SafeZonesApi api = _FakeSafeZonesApi(() async {
      return <SafeZone>[
        SafeZone(
          zoneId: 'SZ-101',
          lat: 19.076,
          lng: 72.8777,
          radius: 300,
          confidence: 'HIGH',
          active: true,
          source: 'AUTO',
        ),
      ];
    });
    final _MemorySafeZonesCache cache = _MemorySafeZonesCache();

    Future<Position> fakeLocation() async {
      return Position(
        longitude: 72.8777,
        latitude: 19.076,
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
      _buildScreen(api, locationProvider: fakeLocation, cache: cache),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('safe-zones-location-btn')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Distance now shown'), findsOneWidget);
    expect(find.byKey(const Key('safe-zone-distance-label')), findsOneWidget);
    expect(find.byKey(const Key('safe-zones-nearest-route-card')), findsOneWidget);
  });

  testWidgets('falls back to cached zones when API fails', (
    WidgetTester tester,
  ) async {
    final SafeZonesApi api = _FakeSafeZonesApi(() async {
      throw Exception('network');
    });
    final _MemorySafeZonesCache cache = _MemorySafeZonesCache()
      ..zones = <SafeZone>[
        SafeZone(
          zoneId: 'SZ-CACHED',
          lat: 19.0,
          lng: 72.8,
          radius: 300,
          confidence: 'HIGH',
          active: true,
          source: 'CACHE',
        ),
      ];

    await tester.pumpWidget(_buildScreen(api, cache: cache));
    await tester.pumpAndSettle();

    expect(
      find.text('Offline mode: showing last saved safe zones.'),
      findsOneWidget,
    );
    expect(find.text('SZ-CACHED'), findsOneWidget);
  });
}
