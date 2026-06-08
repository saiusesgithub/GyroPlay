import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('renders GyroPlay controller screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GyroPlayApp());

    expect(find.text('GyroPlay'), findsOneWidget);
    expect(find.text('PC IPv4 address'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Steering'), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
  });
}
