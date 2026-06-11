import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/app_state.dart';

void main() {
  testWidgets('renders GyroPlay tilt controller screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = AppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(GyroPlayApp(appState: appState));

    expect(find.text('GyroPlay'), findsOneWidget);
    expect(find.text('Pair a PC'), findsOneWidget);
    expect(find.text('Active profile'), findsOneWidget);
    expect(find.text('Assetto Corsa'), findsOneWidget);
  });
}
