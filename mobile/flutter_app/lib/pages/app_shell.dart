import 'package:flutter/material.dart';

import '../services/app_state.dart';
import 'about_page.dart';
import 'controller_page.dart';
import 'home_page.dart';
import 'pair_device_page.dart';
import 'profiles_page.dart';
import 'settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.appState.handleLifecycle(state);
  }

  Future<void> openController() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ControllerPage(appState: widget.appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        appState: widget.appState,
        onPair: () => setState(() => _index = 1),
        onOpenController: openController,
      ),
      PairDevicePage(appState: widget.appState),
      ProfilesPage(appState: widget.appState),
      SettingsPage(appState: widget.appState),
      AboutPage(appState: widget.appState),
    ];

    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(child: pages[_index]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Pair',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: 'Profiles',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune),
                label: 'Settings',
              ),
              NavigationDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: 'About',
              ),
            ],
          ),
        );
      },
    );
  }
}
