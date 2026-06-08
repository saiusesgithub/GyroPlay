import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
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
  static const Duration _networkInterval = Duration(milliseconds: 16);
  static const Duration _uiTiltInterval = Duration(milliseconds: 40);

  final TextEditingController _ipController = TextEditingController();
  final Stopwatch _networkStopwatch = Stopwatch()..start();
  final Stopwatch _uiTiltStopwatch = Stopwatch()..start();

  RawDatagramSocket? _socket;
  InternetAddress? _pcAddress;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  SteeringMode _steeringMode = SteeringMode.tilt;
  double _manualLeftX = 0.0;
  double _steeringValue = 0.0;
  double _rawRollDegrees = 0.0;
  double _currentTiltDegrees = 0.0;
  double? _calibratedRollDegrees;
  bool _invertSteering = false;
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
    _sendSteering(0.0, force: true);
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
      _resetSteering(sendPacket: true);
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
            _resetSteering(sendPacket: true);
            _showSnackBar('Sensor error: $error');
          },
          onDone: () {
            _sensorActive = false;
            _resetSteering(sendPacket: true);
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

      _sendSteering(_steeringValue, force: true);
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
    _resetSteering(sendPacket: true);
    _socket?.close();

    setState(() {
      _socket = null;
      _pcAddress = null;
      _manualLeftX = 0.0;
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
        _steeringValue = smoothedSteering;
      }
    });

    if (steeringChanged) {
      _sendSteering(_steeringValue);
    }
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
    _resetSteering(sendPacket: true);
    _showSnackBar('Tilt center calibrated.');
  }

  void _setInvertSteering(bool value) {
    setState(() {
      _invertSteering = value;
      _steeringValue = 0.0;
    });

    _sendSteering(0.0, force: true);
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

    _sendSteering(0.0, force: true);
  }

  void _onManualSteeringChanged(double value) {
    setState(() {
      _manualLeftX = value;
      _steeringValue = value;
    });

    if (_steeringMode == SteeringMode.manual) {
      _sendSteering(value);
    }
  }

  void _resetSteering({required bool sendPacket}) {
    if (!mounted) {
      if (sendPacket) {
        _sendSteering(0.0, force: true);
      }
      return;
    }

    setState(() {
      _manualLeftX = 0.0;
      _steeringValue = 0.0;
    });

    if (sendPacket) {
      _sendSteering(0.0, force: true);
    }
  }

  void _sendSteering(double leftX, {bool force = false}) {
    final socket = _socket;
    final address = _pcAddress;

    if (socket == null || address == null) {
      return;
    }

    if (!force && _networkStopwatch.elapsed < _networkInterval) {
      return;
    }

    final packet = jsonEncode({
      'type': 'gamepad_update',
      'left_x': leftX.clamp(-1.0, 1.0),
    });

    try {
      socket.send(utf8.encode(packet), address, _udpPort);
      _networkStopwatch.reset();
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
      appBar: AppBar(title: const Text('GyroPlay'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isConnecting
                    ? null
                    : _isConnected
                    ? _disconnect
                    : _connect,
                child: Text(_isConnected ? 'Disconnect' : 'Connect'),
              ),
              const SizedBox(height: 24),
              SegmentedButton<SteeringMode>(
                segments: const [
                  ButtonSegment(
                    value: SteeringMode.tilt,
                    label: Text('Tilt steering'),
                  ),
                  ButtonSegment(
                    value: SteeringMode.manual,
                    label: Text('Manual slider'),
                  ),
                ],
                selected: {_steeringMode},
                onSelectionChanged: (selection) => _setMode(selection.first),
              ),
              const SizedBox(height: 24),
              Text(statusText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(sensorText),
              const SizedBox(height: 24),
              Text('Tilt angle', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '${_currentTiltDegrees.toStringAsFixed(1)} deg',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _sensorActive ? _calibrate : null,
                child: const Text('Calibrate'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Invert steering'),
                value: _invertSteering,
                onChanged: _setInvertSteering,
              ),
              const SizedBox(height: 32),
              Text(
                'Steering value',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _steeringValue.toStringAsFixed(2),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
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
                LinearProgressIndicator(
                  value: (_steeringValue + 1.0) / 2.0,
                  minHeight: 10,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
