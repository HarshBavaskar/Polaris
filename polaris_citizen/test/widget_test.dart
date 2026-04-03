import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/app.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('citizen dashboard shell renders', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CitizenApp());
    await tester.pump();

    expect(find.text('Citizen Dashboard'), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(find.text('EMERGENCY CALL (112)'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    
    // Check some new dashboard keys exist
    expect(find.byKey(const Key('dashboard-call-112')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-primary-alerts')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-refresh-summary')), findsOneWidget);
  });

  testWidgets('primary alerts button opens alerts tab', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CitizenApp());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-primary-alerts')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('dashboard-primary-alerts')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('dashboard-primary-alerts')), findsNothing);
  });

  testWidgets('drawer can return from my reports to dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CitizenApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('drawer-nav-myreports')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('My Reports'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('drawer-nav-dashboard')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('EMERGENCY CALL (112)'), findsOneWidget);
  });
}
