import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/app_shell.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final appState = AppState();
  await appState.load();
  appState.startSensors();

  runApp(GyroPlayApp(appState: appState));
}

class GyroPlayApp extends StatelessWidget {
  const GyroPlayApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final brightness = switch (appState.settings.themeMode) {
          AppThemeMode.light => Brightness.light,
          AppThemeMode.dark => Brightness.dark,
          AppThemeMode.system =>
            MediaQuery.platformBrightnessOf(context),
        };

        return MaterialApp(
          title: 'GyroPlay',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4CC9F0),
              brightness: brightness,
            ),
            scaffoldBackgroundColor: brightness == Brightness.dark
                ? const Color(0xFF0E1318)
                : const Color(0xFFF4F8FB),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          home: AppShell(appState: appState),
        );
      },
    );
  }
}
