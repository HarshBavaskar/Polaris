import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/app.dart';
import 'package:polaris_citizen/features/alerts/alerts_screen.dart';
import 'package:polaris_citizen/features/report/my_reports_screen.dart';
import 'package:polaris_citizen/features/safe_zones/safe_zones_screen.dart';

void main() {
  testWidgets('citizen dashboard shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CitizenApp());

    expect(find.text('Citizen Dashboard'), findsOneWidget);
    expect(find.text('Stay Alert. Report Flooding Fast.'), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Emergency Helplines'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Emergency Helplines'), findsOneWidget);
    expect(find.byKey(const Key('helpline-112')), findsOneWidget);
    expect(find.byKey(const Key('helpline-101')), findsOneWidget);
    expect(find.byKey(const Key('helpline-area-dropdown')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-fetch-location')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('dashboard-fetch-location')), findsOneWidget);
  });

  testWidgets('dashboard quick action opens report tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.byKey(const Key('dashboard-go-report')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Report Flooding'), findsOneWidget);
    expect(find.text('Location Zone'), findsOneWidget);
  });

  testWidgets('dashboard quick action opens alerts tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.byKey(const Key('dashboard-go-alerts')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertsScreen), findsOneWidget);
    expect(find.text('Alerts'), findsWidgets);
  });

  testWidgets('dashboard quick action opens safe zones tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.byKey(const Key('dashboard-go-safezones')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Safe Zones'), findsWidgets);
    expect(find.byType(SafeZonesScreen), findsOneWidget);
  });

  testWidgets('dashboard quick action opens my reports tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.byKey(const Key('dashboard-go-myreports')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MyReportsScreen), findsOneWidget);
    expect(find.text('My Reports'), findsWidgets);
  });
}
