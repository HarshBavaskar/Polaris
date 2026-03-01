import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/app.dart';

void main() {
  testWidgets('citizen dashboard shell renders', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CitizenApp());
    await tester.pump(const Duration(milliseconds: 2100));

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

  testWidgets('live snapshot button opens alerts tab', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CitizenApp());
    await tester.pump(const Duration(milliseconds: 2100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-live-view-alerts')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('dashboard-live-view-alerts')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('dashboard-live-view-alerts')), findsNothing);
  });
}
