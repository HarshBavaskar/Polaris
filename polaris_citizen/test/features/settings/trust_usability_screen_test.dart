import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/core/settings/citizen_preferences.dart';
import 'package:polaris_citizen/core/settings/citizen_preferences_scope.dart';
import 'package:polaris_citizen/features/settings/trust_usability_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('data saver toggle updates citizen preferences', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final CitizenPreferencesController controller =
        CitizenPreferencesController();
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: CitizenPreferencesScope(
          controller: controller,
          child: const Scaffold(body: TrustUsabilityScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.dataSaverEnabled, isFalse);
    await tester.tap(find.byKey(const Key('trust-data-saver-toggle')));
    await tester.pumpAndSettle();
    expect(controller.dataSaverEnabled, isTrue);
  });
}
