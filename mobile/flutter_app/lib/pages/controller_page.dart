import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/app_state.dart';
import '../widgets/app_widgets.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage>
    with WidgetsBindingObserver {
  bool _calibrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterControllerMode();
  }

  Future<void> _enterControllerMode() async {
    widget.appState.setControllerModeActive(true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (widget.appState.settings.keepScreenAwake) {
      await WakelockPlus.enable();
    }
  }

  Future<void> _exitControllerMode() async {
    widget.appState.resetControls(sendPacket: true);
    widget.appState.setControllerModeActive(false);
    await WakelockPlus.disable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    widget.appState.handleLifecycle(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      await _exitControllerMode();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_exitControllerMode());
    super.dispose();
  }

  Future<void> _calibrate() async {
    if (!widget.appState.sensorActive || _calibrating) return;

    setState(() => _calibrating = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibrate steering'),
        content: const Text('Hold your phone centered like a steering wheel, then confirm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Set Center'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.appState.calibrateNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Steering center calibrated.')),
        );
      }
    }

    if (mounted) setState(() => _calibrating = false);
  }

  Future<void> _exit() async {
    await _exitControllerMode();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final state = widget.appState;
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 390;
                return Padding(
                  padding: EdgeInsets.all(compact ? 10 : 14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopBar(
                              appState: state,
                              onCalibrate: state.sensorActive ? _calibrate : null,
                              onExit: _exit,
                            ),
                            if (state.connectionStatus == ConnectionStatus.connectionLost)
                              _ConnectionWarning(appState: state),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _SteeringPanel(appState: state),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _HoldButton(
                                    label: 'Gear Down',
                                    icon: Icons.keyboard_double_arrow_down,
                                    isPressed: state.gearDown,
                                    onChanged: (pressed) =>
                                        state.setButton('gear_down', pressed),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HoldButton(
                                    label: 'Gear Up',
                                    icon: Icons.keyboard_double_arrow_up,
                                    isPressed: state.gearUp,
                                    onChanged: (pressed) =>
                                        state.setButton('gear_up', pressed),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HoldButton(
                                    label: 'Handbrake',
                                    icon: Icons.pan_tool_alt_outlined,
                                    isPressed: state.handbrake,
                                    onChanged: (pressed) =>
                                        state.setButton('handbrake', pressed),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Expanded(
                              child: _Pedal(
                                label: 'Brake',
                                icon: Icons.stop_circle_outlined,
                                value: state.brake,
                                color: Colors.redAccent,
                                onChanged: (value) =>
                                    state.setPedalValue('brake', value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Pedal(
                                label: 'Throttle',
                                icon: Icons.speed,
                                value: state.throttle,
                                color: Theme.of(context).colorScheme.primary,
                                onChanged: (value) =>
                                    state.setPedalValue('throttle', value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appState,
    required this.onCalibrate,
    required this.onExit,
  });

  final AppState appState;
  final VoidCallback? onCalibrate;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final connected = appState.connectionStatus == ConnectionStatus.connected;
    return Row(
      children: [
        StatusPill(
          icon: connected ? Icons.link : Icons.link_off,
          label: connected ? 'Connected' : 'Disconnected',
          color: connected ? Colors.tealAccent : Colors.orangeAccent,
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onCalibrate,
          icon: const Icon(Icons.center_focus_strong),
          label: const Text('Calibrate'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: onExit,
          icon: const Icon(Icons.close_fullscreen),
          label: const Text('Exit'),
        ),
      ],
    );
  }
}

class _ConnectionWarning extends StatelessWidget {
  const _ConnectionWarning({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orangeAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(appState.lastFriendlyError ?? 'Connection lost. Controls were reset.'),
          ),
          TextButton(
            onPressed: appState.connectManual,
            child: const Text('Reconnect'),
          ),
        ],
      ),
    );
  }
}

class _SteeringPanel extends StatelessWidget {
  const _SteeringPanel({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    if (appState.steeringMode == SteeringMode.manual) {
      return AppCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Manual Steering', style: Theme.of(context).textTheme.titleLarge),
            Slider(
              value: appState.manualLeftX,
              min: -1,
              max: 1,
              divisions: 200,
              onChanged: appState.setManualSteering,
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.screen_rotation_alt,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('Tilt Steering', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 18,
              value: (appState.steeringValue + 1) / 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pedal extends StatelessWidget {
  const _Pedal({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void updateFromOffset(Offset localPosition) {
          final nextValue =
              (1.0 - (localPosition.dy / constraints.maxHeight)).clamp(0.0, 1.0);
          onChanged(nextValue);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateFromOffset(details.localPosition),
          onTapUp: (_) => onChanged(0.0),
          onTapCancel: () => onChanged(0.0),
          onVerticalDragDown: (details) => updateFromOffset(details.localPosition),
          onVerticalDragUpdate: (details) => updateFromOffset(details.localPosition),
          onVerticalDragEnd: (_) => onChanged(0.0),
          onVerticalDragCancel: () => onChanged(0.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FractionallySizedBox(
                  heightFactor: value,
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 34, color: color),
                      const SizedBox(height: 10),
                      Text(label, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.label,
    required this.icon,
    required this.isPressed,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool isPressed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      onLongPressStart: (_) => onChanged(true),
      onLongPressEnd: (_) => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPressed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
