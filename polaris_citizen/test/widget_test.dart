import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/app.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_screen.dart';

void main() {
  testWidgets('citizen dashboard shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CitizenApp());

    expect(find.text('Citizen Dashboard'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Safe Zones'), findsOneWidget);
    expect(find.text('Stay Alert. Report Flooding Fast.'), findsOneWidget);
  });

  testWidgets('navigates to report tab', (WidgetTester tester) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(find.text('Report Flooding'), findsOneWidget);
    expect(find.text('Flood Photo'), findsOneWidget);
    expect(find.text('Flooding Level'), findsOneWidget);
  });

  testWidgets('dashboard quick action opens report tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.byKey(const Key('dashboard-go-report')));
    await tester.pumpAndSettle();

    expect(find.text('Report Flooding'), findsOneWidget);
    expect(find.text('Submit Water Level'), findsOneWidget);
  });

  testWidgets('dashboard quick action opens safe zones tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.byKey(const Key('dashboard-go-safezones')));
    await tester.pumpAndSettle();

    expect(find.text('Safe Zones'), findsWidgets);
    expect(find.byType(SafeZonesScreen), findsOneWidget);
  });
}
