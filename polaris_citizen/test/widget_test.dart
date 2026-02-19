import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_citizen/app.dart';

void main() {
  testWidgets('citizen dashboard shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CitizenApp());

    expect(find.text('Citizen Dashboard'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Safe Zones'), findsOneWidget);
  });

  testWidgets('navigates to report tab', (WidgetTester tester) async {
    await tester.pumpWidget(const CitizenApp());

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(find.text('Report Flooding'), findsOneWidget);
    expect(find.text('Flood Photo'), findsOneWidget);
    expect(find.text('Flooding Level'), findsOneWidget);
  });
}
