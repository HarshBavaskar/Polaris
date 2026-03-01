import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/core/settings/citizen_preferences.dart';
import 'package:polaris_citizen/core/settings/citizen_preferences_scope.dart';
import 'package:polaris_citizen/features/alerts/alerts_screen.dart';
import 'package:polaris_citizen/screens/citizen_dashboard_screen.dart';

Widget _buildShell({Stream<int>? tabNavigationStream}) {
  final CitizenPreferencesController preferences =
      CitizenPreferencesController();
  return CitizenPreferencesScope(
    controller: preferences,
    child: MaterialApp(
      home: CitizenDashboardScreen(tabNavigationStream: tabNavigationStream),
    ),
  );
}

void main() {
  testWidgets('opens alerts tab from tab navigation stream', (
    WidgetTester tester,
  ) async {
    final StreamController<int> controller = StreamController<int>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildShell(tabNavigationStream: controller.stream),
    );
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('Citizen Dashboard'), findsOneWidget);

    controller.add(1);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertsScreen), findsOneWidget);
    expect(find.text('Alerts'), findsWidgets);
  });
}
