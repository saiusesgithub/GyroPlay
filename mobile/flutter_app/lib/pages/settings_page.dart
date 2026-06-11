import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../widgets/app_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _preferredPcController;

  @override
  void initState() {
    super.initState();
    _preferredPcController = TextEditingController(
      text: widget.appState.settings.preferredPc,
    );
  }

  @override
  void dispose() {
    _preferredPcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return PageScaffold(
      title: 'Settings',
      subtitle: 'Adjust steering feel, connection preferences, and app behavior.',
      children: [
        _Section(
          title: 'Steering',
          children: [
            SettingSlider(
              label: 'Dead zone',
              value: appState.settings.deadZoneDegrees,
              min: 0,
              max: 10,
              divisions: 100,
              displayValue:
                  '${appState.settings.deadZoneDegrees.toStringAsFixed(1)} deg',
              onChanged: (value) =>
                  appState.updateSettings(deadZoneDegrees: value),
            ),
            SettingSlider(
              label: 'Maximum tilt angle',
              value: appState.settings.maxTiltDegrees,
              min: 20,
              max: 90,
              divisions: 140,
              displayValue:
                  '${appState.settings.maxTiltDegrees.toStringAsFixed(1)} deg',
              onChanged: (value) =>
                  appState.updateSettings(maxTiltDegrees: value),
            ),
            SettingSlider(
              label: 'Sensitivity',
              value: appState.settings.sensitivity,
              min: 0.5,
              max: 2,
              divisions: 150,
              displayValue:
                  '${appState.settings.sensitivity.toStringAsFixed(2)}x',
              onChanged: (value) => appState.updateSettings(sensitivity: value),
            ),
            SettingSlider(
              label: 'Smoothing',
              value: appState.settings.smoothing,
              min: 0,
              max: 0.5,
              divisions: 100,
              displayValue: appState.settings.smoothing.toStringAsFixed(2),
              onChanged: (value) => appState.updateSettings(smoothing: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Invert steering'),
              value: appState.settings.invertSteering,
              onChanged: (value) =>
                  appState.updateSettings(invertSteering: value),
            ),
          ],
        ),
        _Section(
          title: 'Connection',
          children: [
            TextField(
              controller: _preferredPcController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preferred PC',
                hintText: '192.168.1.20',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              onSubmitted: (value) =>
                  appState.updateSettings(preferredPc: value.trim()),
              onEditingComplete: () => appState.updateSettings(
                preferredPc: _preferredPcController.text.trim(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reconnect automatically'),
              subtitle: const Text('Remember the last PC for future pairing.'),
              value: appState.settings.reconnectAutomatically,
              onChanged: (value) =>
                  appState.updateSettings(reconnectAutomatically: value),
            ),
          ],
        ),
        _Section(
          title: 'App',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptics'),
              value: appState.settings.haptics,
              onChanged: (value) => appState.updateSettings(haptics: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep screen awake in controller mode'),
              value: appState.settings.keepScreenAwake,
              onChanged: (value) =>
                  appState.updateSettings(keepScreenAwake: value),
            ),
            DropdownButtonFormField<AppThemeMode>(
              initialValue: appState.settings.themeMode,
              decoration: const InputDecoration(
                labelText: 'Theme',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('Light'),
                ),
              ],
              onChanged: (value) {
                if (value != null) appState.updateSettings(themeMode: value);
              },
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: appState.resetSettingsToDefaults,
          icon: const Icon(Icons.restore),
          label: const Text('Reset to Defaults'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
