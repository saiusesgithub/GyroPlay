import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('renders GyroPlay tilt controller screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GyroPlayApp());

    expect(find.text('GyroPlay'), findsOneWidget);
    expect(find.text('PC IPv4 address'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Tilt steering'), findsOneWidget);
    expect(find.text('Manual slider'), findsOneWidget);
    expect(find.text('Calibrate'), findsOneWidget);
    expect(find.text('Steering value'), findsOneWidget);
  });
}
