import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const GyroPlayApp());
}

enum SteeringMode { tilt, manual }

class GyroPlayApp extends StatelessWidget {
  const GyroPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GyroPlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CC9F0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101418),
        useMaterial3: true,
      ),
      home: const GyroPlayHome(),
    );
  }
}

class GyroPlayHome extends StatefulWidget {
  const GyroPlayHome({super.key});

  @override
  State<GyroPlayHome> createState() => _GyroPlayHomeState();
}

class _GyroPlayHomeState extends State<GyroPlayHome>
    with WidgetsBindingObserver {
  static const int _udpPort = 5005;
  static const double _fullSteeringTiltDegrees = 45.0;
  static const double _deadZoneDegrees = 3.0;
  static const double _smoothingAlpha = 0.12;
  static const double _minimumSteeringChange = 0.01;
  static const Duration _sendInterval = Duration(milliseconds: 16);
  static const Duration _uiTiltInterval = Duration(milliseconds: 40);

  final TextEditingController _ipController = TextEditingController();
  final Stopwatch _uiTiltStopwatch = Stopwatch()..start();

  RawDatagramSocket? _socket;
  InternetAddress? _pcAddress;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _sendTimer;

  SteeringMode _steeringMode = SteeringMode.tilt;
  double _manualLeftX = 0.0;
  double _steeringValue = 0.0;
  double _rawRollDegrees = 0.0;
  double _currentTiltDegrees = 0.0;
  double _throttle = 0.0;
  double _brake = 0.0;
  double? _calibratedRollDegrees;
  bool _invertSteering = false;
  bool _gearUp = false;
  bool _gearDown = false;
  bool _handbrake = false;
  bool _isConnecting = false;
  bool _sensorActive = false;

  bool get _isConnected => _socket != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSensors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendNeutralPacket();
    _sendTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _socket?.close();
    _ipController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _resetControls(sendPacket: true);
    }
  }

  void _startSensors() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          _handleAccelerometerEvent,
          onError: (Object error) {
            _sensorActive = false;
            _resetControls(sendPacket: true);
            _showSnackBar('Sensor error: $error');
          },
          onDone: () {
            _sensorActive = false;
            _resetControls(sendPacket: true);
          },
          cancelOnError: false,
        );
  }

  Future<void> _connect() async {
    final ipText = _ipController.text.trim();
    final address = InternetAddress.tryParse(ipText);

    if (address == null || address.type != InternetAddressType.IPv4) {
      _showSnackBar('Enter a valid PC IPv4 address.');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      if (!mounted) {
        socket.close();
        return;
      }

      setState(() {
        _socket = socket;
        _pcAddress = address;
        _isConnecting = false;
      });

      _sendControllerState();
      _sendTimer?.cancel();
      _sendTimer = Timer.periodic(_sendInterval, (_) => _sendControllerState());
      _showSnackBar('Connected to ${address.address}:$_udpPort');
    } on SocketException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConnecting = false;
      });
      _showSnackBar('Socket error: ${error.message}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConnecting = false;
      });
      _showSnackBar('Connection failed: $error');
    }
  }

  void _disconnect() {
    _resetControls(sendPacket: true);
    _sendTimer?.cancel();
    _sendTimer = null;
    _socket?.close();

    setState(() {
      _socket = null;
      _pcAddress = null;
    });

    _showSnackBar('Disconnected.');
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final rollDegrees = _landscapeRollDegrees(event);
    final centerDegrees = _calibratedRollDegrees ?? rollDegrees;
    final relativeDegrees = _normalizeDegrees(rollDegrees - centerDegrees);
    final effectiveDegrees = _invertSteering
        ? -relativeDegrees
        : relativeDegrees;
    final targetSteering = _steeringFromRoll(effectiveDegrees);
    var smoothedSteering =
        _steeringValue + _smoothingAlpha * (targetSteering - _steeringValue);

    if (targetSteering == 0.0 && smoothedSteering.abs() < 0.01) {
      smoothedSteering = 0.0;
    }

    final steeringChanged =
        _steeringMode == SteeringMode.tilt &&
        (smoothedSteering - _steeringValue).abs() >= _minimumSteeringChange;
    final shouldUpdateTiltUi = _uiTiltStopwatch.elapsed >= _uiTiltInterval;

    if (!steeringChanged && !shouldUpdateTiltUi && _sensorActive) {
      return;
    }

    setState(() {
      _sensorActive = true;
      _rawRollDegrees = rollDegrees;
      _calibratedRollDegrees ??= rollDegrees;

      if (shouldUpdateTiltUi) {
        _currentTiltDegrees = effectiveDegrees;
        _uiTiltStopwatch.reset();
      }

      if (steeringChanged) {
        _steeringValue = smoothedSteering.clamp(-1.0, 1.0);
      }
    });
  }

  double _landscapeRollDegrees(AccelerometerEvent event) {
    return math.atan2(event.y, event.x) * 180.0 / math.pi;
  }

  double _normalizeDegrees(double degrees) {
    var normalized = degrees;

    while (normalized > 180.0) {
      normalized -= 360.0;
    }

    while (normalized < -180.0) {
      normalized += 360.0;
    }

    return normalized;
  }

  double _steeringFromRoll(double rollDegrees) {
    if (rollDegrees.abs() < _deadZoneDegrees) {
      return 0.0;
    }

    final adjustedDegrees = rollDegrees.abs() - _deadZoneDegrees;
    final steeringRange = _fullSteeringTiltDegrees - _deadZoneDegrees;

    return (adjustedDegrees / steeringRange).clamp(0.0, 1.0) * rollDegrees.sign;
  }

  void _calibrate() {
    _calibratedRollDegrees = _rawRollDegrees;
    _resetSteeringOnly();
    _sendNeutralPacket();
    _showSnackBar('Tilt center calibrated.');
  }

  void _setInvertSteering(bool value) {
    setState(() {
      _invertSteering = value;
      _steeringValue = 0.0;
    });

    _sendNeutralPacket();
  }

  void _setMode(SteeringMode mode) {
    if (_steeringMode == mode) {
      return;
    }

    setState(() {
      _steeringMode = mode;
      _manualLeftX = 0.0;
      _steeringValue = 0.0;
    });

    _sendNeutralPacket();
  }

  void _onManualSteeringChanged(double value) {
    setState(() {
      _manualLeftX = value;
      _steeringValue = value;
    });
  }

  void _setPedalValue(String pedal, double value) {
    final clampedValue = value.clamp(0.0, 1.0);

    setState(() {
      if (pedal == 'throttle') {
        _throttle = clampedValue;
      } else {
        _brake = clampedValue;
      }
    });
  }

  void _setButton(String button, bool isPressed) {
    setState(() {
      if (button == 'gear_up') {
        _gearUp = isPressed;
      } else if (button == 'gear_down') {
        _gearDown = isPressed;
      } else {
        _handbrake = isPressed;
      }
    });
  }

  void _resetSteeringOnly() {
    if (!mounted) {
      return;
    }

    setState(() {
      _manualLeftX = 0.0;
      _steeringValue = 0.0;
    });
  }

  void _resetControls({required bool sendPacket}) {
    if (!mounted) {
      if (sendPacket) {
        _sendNeutralPacket();
      }
      return;
    }

    setState(() {
      _manualLeftX = 0.0;
      _steeringValue = 0.0;
      _throttle = 0.0;
      _brake = 0.0;
      _gearUp = false;
      _gearDown = false;
      _handbrake = false;
    });

    if (sendPacket) {
      _sendNeutralPacket();
    }
  }

  void _sendNeutralPacket() {
    _sendControllerState(
      leftX: 0.0,
      throttle: 0.0,
      brake: 0.0,
      gearUp: false,
      gearDown: false,
      handbrake: false,
    );
  }

  void _sendControllerState({
    double? leftX,
    double? throttle,
    double? brake,
    bool? gearUp,
    bool? gearDown,
    bool? handbrake,
  }) {
    final socket = _socket;
    final address = _pcAddress;

    if (socket == null || address == null) {
      return;
    }

    final packet = jsonEncode({
      'version': 1,
      'type': 'gamepad_update',
      'left_x': (leftX ?? _steeringValue).clamp(-1.0, 1.0),
      'throttle': (throttle ?? _throttle).clamp(0.0, 1.0),
      'brake': (brake ?? _brake).clamp(0.0, 1.0),
      'gear_up': gearUp ?? _gearUp,
      'gear_down': gearDown ?? _gearDown,
      'handbrake': handbrake ?? _handbrake,
    });

    try {
      socket.send(utf8.encode(packet), address, _udpPort);
    } on SocketException catch (error) {
      _showSnackBar('Socket error: ${error.message}');
    } catch (error) {
      _showSnackBar('Failed to send packet: $error');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _isConnected ? 'Connected' : 'Disconnected';
    final sensorText = _sensorActive ? 'Sensor active' : 'Sensor waiting';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'GyroPlay',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      enabled: !_isConnected && !_isConnecting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'PC IPv4 address',
                        hintText: '192.168.1.20',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _isConnecting
                          ? null
                          : _isConnected
                          ? _disconnect
                          : _connect,
                      child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<SteeringMode>(
                      segments: const [
                        ButtonSegment(
                          value: SteeringMode.tilt,
                          label: Text('Tilt'),
                        ),
                        ButtonSegment(
                          value: SteeringMode.manual,
                          label: Text('Manual'),
                        ),
                      ],
                      selected: {_steeringMode},
                      onSelectionChanged: (selection) =>
                          _setMode(selection.first),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Invert steering'),
                      value: _invertSteering,
                      onChanged: _setInvertSteering,
                    ),
                    OutlinedButton(
                      onPressed: _sensorActive ? _calibrate : null,
                      child: const Text('Calibrate'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(sensorText),
                    const SizedBox(height: 12),
                    Text('Roll: ${_currentTiltDegrees.toStringAsFixed(1)} deg'),
                    Text(
                      'Steering: ${_steeringValue.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_steeringMode == SteeringMode.manual)
                      Slider(
                        value: _manualLeftX,
                        min: -1.0,
                        max: 1.0,
                        divisions: 200,
                        label: _manualLeftX.toStringAsFixed(2),
                        onChanged: _onManualSteeringChanged,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(
                          value: (_steeringValue + 1.0) / 2.0,
                          minHeight: 12,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _HoldButton(
                            label: 'Gear down',
                            isPressed: _gearDown,
                            onChanged: (pressed) =>
                                _setButton('gear_down', pressed),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HoldButton(
                            label: 'Gear up',
                            isPressed: _gearUp,
                            onChanged: (pressed) =>
                                _setButton('gear_up', pressed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _HoldButton(
                      label: 'Handbrake',
                      isPressed: _handbrake,
                      onChanged: (pressed) => _setButton('handbrake', pressed),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: _Pedal(
                        label: 'Brake',
                        value: _brake,
                        onChanged: (value) => _setPedalValue('brake', value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Pedal(
                        label: 'Throttle',
                        value: _throttle,
                        onChanged: (value) => _setPedalValue('throttle', value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pedal extends StatelessWidget {
  const _Pedal({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void updateFromOffset(Offset localPosition) {
          final height = constraints.maxHeight;
          final nextValue = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);
          onChanged(nextValue);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateFromOffset(details.localPosition),
          onTapUp: (_) => onChanged(0.0),
          onTapCancel: () => onChanged(0.0),
          onVerticalDragDown: (details) =>
              updateFromOffset(details.localPosition),
          onVerticalDragUpdate: (details) =>
              updateFromOffset(details.localPosition),
          onVerticalDragEnd: (_) => onChanged(0.0),
          onVerticalDragCancel: () => onChanged(0.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FractionallySizedBox(
                  heightFactor: value,
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(value.toStringAsFixed(2)),
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
    required this.isPressed,
    required this.onChanged,
  });

  final String label;
  final bool isPressed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: AnimatedContainer(
        duration: Duration.zero,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPressed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
