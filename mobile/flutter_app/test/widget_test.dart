import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('renders GyroPlay tilt controller screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GyroPlayApp());

    expect(find.text('GyroPlay'), findsOneWidget);
    expect(find.text('PC IPv4 address'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Tilt'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Calibrate'), findsOneWidget);
    expect(find.text('Throttle'), findsOneWidget);
    expect(find.text('Brake'), findsOneWidget);
    expect(find.text('Gear up'), findsOneWidget);
    expect(find.text('Gear down'), findsOneWidget);
    expect(find.text('Handbrake'), findsOneWidget);
  });
}
