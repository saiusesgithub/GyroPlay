import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const GyroPlayApp());
}

enum SteeringMode { tilt, manual }

enum ConnectionStatus { disconnected, connecting, connected, connectionLost }

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
  static const int _defaultUdpPort = 5005;
  static const String _profileName = 'Assetto Corsa';
  static const double _defaultDeadZoneDegrees = 2.0;
  static const double _defaultMaxTiltDegrees = 45.0;
  static const double _defaultSensitivity = 1.0;
  static const double _defaultSmoothing = 0.12;
  static const bool _defaultInvertSteering = false;
  static const Duration _sendInterval = Duration(milliseconds: 16);
  static const Duration _uiTiltInterval = Duration(milliseconds: 40);

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _pairingTokenController = TextEditingController();
  final Stopwatch _uiTiltStopwatch = Stopwatch()..start();

  RawDatagramSocket? _socket;
  InternetAddress? _pcAddress;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Timer? _sendTimer;
  Timer? _heartbeatTimer;
  Timer? _connectTimeoutTimer;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  SteeringMode _steeringMode = SteeringMode.tilt;
  String? _sessionId;
  int _pcPort = _defaultUdpPort;
  double _manualLeftX = 0.0;
  double _steeringValue = 0.0;
  double _rawRollDegrees = 0.0;
  double _currentTiltDegrees = 0.0;
  double _targetSteeringValue = 0.0;
  double _deadZoneDegrees = _defaultDeadZoneDegrees;
  double _maxTiltDegrees = _defaultMaxTiltDegrees;
  double _steeringSensitivity = _defaultSensitivity;
  double _smoothing = _defaultSmoothing;
  double _throttle = 0.0;
  double _brake = 0.0;
  double? _calibratedRollDegrees;
  bool _invertSteering = _defaultInvertSteering;
  bool _gearUp = false;
  bool _gearDown = false;
  bool _handbrake = false;
  bool _sensorActive = false;

  bool get _isConnected => _connectionStatus == ConnectionStatus.connected;
  bool get _isConnecting => _connectionStatus == ConnectionStatus.connecting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _startSensors();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _deadZoneDegrees =
          prefs.getDouble('steering_dead_zone') ?? _defaultDeadZoneDegrees;
      _maxTiltDegrees =
          prefs.getDouble('steering_max_tilt') ?? _defaultMaxTiltDegrees;
      _steeringSensitivity =
          prefs.getDouble('steering_sensitivity') ?? _defaultSensitivity;
      _smoothing = prefs.getDouble('steering_smoothing') ?? _defaultSmoothing;
      _invertSteering =
          prefs.getBool('steering_invert') ?? _defaultInvertSteering;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('steering_dead_zone', _deadZoneDegrees);
    await prefs.setDouble('steering_max_tilt', _maxTiltDegrees);
    await prefs.setDouble('steering_sensitivity', _steeringSensitivity);
    await prefs.setDouble('steering_smoothing', _smoothing);
    await prefs.setBool('steering_invert', _invertSteering);
  }

  void _updateSettings({
    double? deadZoneDegrees,
    double? maxTiltDegrees,
    double? steeringSensitivity,
    double? smoothing,
    bool? invertSteering,
  }) {
    setState(() {
      if (deadZoneDegrees != null) {
        _deadZoneDegrees = deadZoneDegrees;
      }
      if (maxTiltDegrees != null) {
        _maxTiltDegrees = maxTiltDegrees;
      }
      if (steeringSensitivity != null) {
        _steeringSensitivity = steeringSensitivity;
      }
      if (smoothing != null) {
        _smoothing = smoothing;
      }
      if (invertSteering != null) {
        _invertSteering = invertSteering;
        _steeringValue = 0.0;
        _targetSteeringValue = 0.0;
      }
    });

    _saveSettings();
  }

  void _resetSettingsToDefaults() {
    _updateSettings(
      deadZoneDegrees: _defaultDeadZoneDegrees,
      maxTiltDegrees: _defaultMaxTiltDegrees,
      steeringSensitivity: _defaultSensitivity,
      smoothing: _defaultSmoothing,
      invertSteering: _defaultInvertSteering,
    );
    _showSnackBar('Assetto Corsa profile restored.');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendNeutralPacket();
    _sendTimer?.cancel();
    _heartbeatTimer?.cancel();
    _connectTimeoutTimer?.cancel();
    _socketSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _socket?.close();
    _ipController.dispose();
    _pairingTokenController.dispose();
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
    final pairingToken = _pairingTokenController.text.trim();
    final address = InternetAddress.tryParse(ipText);

    if (address == null || address.type != InternetAddressType.IPv4) {
      _showSnackBar('Enter a valid PC IPv4 address.');
      return;
    }

    if (pairingToken.isEmpty) {
      _showSnackBar('Scan a QR code or enter a pairing token.');
      return;
    }

    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
      _sessionId = null;
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
      });

      _socketSubscription?.cancel();
      _socketSubscription = socket.listen(_handleSocketEvent);
      _sendHello();
      _connectTimeoutTimer?.cancel();
      _connectTimeoutTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || _connectionStatus != ConnectionStatus.connecting) {
          return;
        }

        _markConnectionLost('Connection lost: no hello_ack received.');
      });
      _showSnackBar('Connecting to ${address.address}:$_pcPort');
    } on SocketException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connectionStatus = ConnectionStatus.disconnected;
      });
      _showSnackBar('Socket error: ${error.message}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connectionStatus = ConnectionStatus.disconnected;
      });
      _showSnackBar('Connection failed: $error');
    }
  }

  Future<void> _scanQrCode() async {
    final payload = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _QrScannerPage()));

    if (!mounted || payload == null) {
      return;
    }

    try {
      final pairing = _parsePairingPayload(payload);
      _ipController.text = pairing.host;
      _pairingTokenController.text = pairing.pairingToken;

      setState(() {
        _pcPort = pairing.port;
      });

      await _connect();
    } catch (error) {
      _showSnackBar(error.toString());
    }
  }

  _PairingPayload _parsePairingPayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid QR code.');
    }

    if (decoded['version'] != 1 || decoded['type'] != 'gyroplay_pairing') {
      throw const FormatException('Not a GyroPlay pairing code.');
    }

    final host = decoded['host'];
    final port = decoded['port'];
    final pairingToken = decoded['pairing_token'];
    final expiresAtText = decoded['expires_at'];

    if (host is! String ||
        InternetAddress.tryParse(host)?.type != InternetAddressType.IPv4) {
      throw const FormatException('Pairing code has an invalid PC IP address.');
    }

    if (port is! int || port < 1 || port > 65535) {
      throw const FormatException('Pairing code has an invalid UDP port.');
    }

    if (pairingToken is! String || pairingToken.isEmpty) {
      throw const FormatException('Pairing code has an invalid token.');
    }

    if (expiresAtText is! String) {
      throw const FormatException('Pairing code is missing expiry.');
    }

    final expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null) {
      throw const FormatException('Pairing code has an invalid expiry.');
    }

    if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
      throw const FormatException(
        'Pairing code expired. Refresh it on the PC.',
      );
    }

    return _PairingPayload(host: host, port: port, pairingToken: pairingToken);
  }

  void _disconnect() {
    _resetControls(sendPacket: true);
    _sendTimer?.cancel();
    _sendTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();

    setState(() {
      _socket = null;
      _pcAddress = null;
      _sessionId = null;
      _connectionStatus = ConnectionStatus.disconnected;
    });

    _showSnackBar('Disconnected.');
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    final datagram = _socket?.receive();
    if (datagram == null) {
      return;
    }

    try {
      final packet = jsonDecode(utf8.decode(datagram.data));
      if (packet is! Map<String, dynamic>) {
        return;
      }

      if (packet['version'] == 1 &&
          packet['type'] == 'hello_ack' &&
          packet['session_id'] is String) {
        _handleHelloAck(packet['session_id'] as String);
      }
    } catch (error) {
      _showSnackBar('Failed to parse engine response: $error');
    }
  }

  void _handleHelloAck(String sessionId) {
    _connectTimeoutTimer?.cancel();

    setState(() {
      _sessionId = sessionId;
      _connectionStatus = ConnectionStatus.connected;
    });

    _sendControllerState();
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(_sendInterval, (_) => _sendControllerState());
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sendHeartbeat(),
    );
    _showSnackBar('Connected.');
  }

  void _markConnectionLost(String message) {
    _resetControls(sendPacket: false);
    _sendTimer?.cancel();
    _sendTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();

    setState(() {
      _socket = null;
      _pcAddress = null;
      _sessionId = null;
      _connectionStatus = ConnectionStatus.connectionLost;
    });

    _showSnackBar(message);
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
        _steeringValue + _smoothing * (targetSteering - _steeringValue);

    final steeringChanged =
        _steeringMode == SteeringMode.tilt &&
        smoothedSteering != _steeringValue;
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

      _targetSteeringValue = targetSteering;

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
    final steeringRange = (_maxTiltDegrees - _deadZoneDegrees).clamp(1.0, 90.0);
    final scaledSteering =
        (adjustedDegrees / steeringRange) * _steeringSensitivity;

    return scaledSteering.clamp(0.0, 1.0) * rollDegrees.sign;
  }

  void _calibrate() {
    setState(() {
      _calibratedRollDegrees = _rawRollDegrees;
      _currentTiltDegrees = 0.0;
      _manualLeftX = 0.0;
      _steeringValue = 0.0;
      _targetSteeringValue = 0.0;
    });
    _sendNeutralPacket();
    _showSnackBar('Tilt center calibrated.');
  }

  void _setMode(SteeringMode mode) {
    if (_steeringMode == mode) {
      return;
    }

    setState(() {
      _steeringMode = mode;
      _manualLeftX = 0.0;
      _steeringValue = 0.0;
      _targetSteeringValue = 0.0;
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
      _targetSteeringValue = 0.0;
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

  void _sendHello() {
    final socket = _socket;
    final address = _pcAddress;

    if (socket == null || address == null) {
      return;
    }

    final packet = jsonEncode({
      'version': 1,
      'type': 'hello',
      'device_name': 'Android Phone',
      'pairing_token': _pairingTokenController.text.trim(),
    });

    try {
      socket.send(utf8.encode(packet), address, _pcPort);
    } on SocketException catch (error) {
      _markConnectionLost('Socket error: ${error.message}');
    } catch (error) {
      _markConnectionLost('Failed to send hello: $error');
    }
  }

  void _sendHeartbeat() {
    final socket = _socket;
    final address = _pcAddress;
    final sessionId = _sessionId;

    if (socket == null || address == null || sessionId == null) {
      return;
    }

    final packet = jsonEncode({
      'version': 1,
      'type': 'heartbeat',
      'session_id': sessionId,
    });

    try {
      socket.send(utf8.encode(packet), address, _pcPort);
    } on SocketException catch (error) {
      _markConnectionLost('Socket error: ${error.message}');
    } catch (error) {
      _markConnectionLost('Failed to send heartbeat: $error');
    }
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
    final sessionId = _sessionId;

    if (socket == null || address == null || sessionId == null) {
      return;
    }

    final packet = jsonEncode({
      'version': 1,
      'type': 'gamepad_update',
      'session_id': sessionId,
      'left_x': (leftX ?? _steeringValue).clamp(-1.0, 1.0),
      'throttle': (throttle ?? _throttle).clamp(0.0, 1.0),
      'brake': (brake ?? _brake).clamp(0.0, 1.0),
      'gear_up': gearUp ?? _gearUp,
      'gear_down': gearDown ?? _gearDown,
      'handbrake': handbrake ?? _handbrake,
    });

    try {
      socket.send(utf8.encode(packet), address, _pcPort);
    } on SocketException catch (error) {
      _markConnectionLost('Socket error: ${error.message}');
    } catch (error) {
      _markConnectionLost('Failed to send packet: $error');
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

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateSheet(VoidCallback action) {
              action();
              setSheetState(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Controller Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text('Profile: $_profileName'),
                    const SizedBox(height: 18),
                    _SettingsSlider(
                      label: 'Steering dead zone',
                      value: _deadZoneDegrees,
                      min: 0.0,
                      max: 10.0,
                      divisions: 100,
                      displayValue:
                          '${_deadZoneDegrees.toStringAsFixed(1)} deg',
                      onChanged: (value) => updateSheet(
                        () => _updateSettings(deadZoneDegrees: value),
                      ),
                    ),
                    _SettingsSlider(
                      label: 'Maximum tilt angle',
                      value: _maxTiltDegrees,
                      min: 20.0,
                      max: 90.0,
                      divisions: 140,
                      displayValue: '${_maxTiltDegrees.toStringAsFixed(1)} deg',
                      onChanged: (value) => updateSheet(
                        () => _updateSettings(maxTiltDegrees: value),
                      ),
                    ),
                    _SettingsSlider(
                      label: 'Steering sensitivity',
                      value: _steeringSensitivity,
                      min: 0.5,
                      max: 2.0,
                      divisions: 150,
                      displayValue:
                          '${_steeringSensitivity.toStringAsFixed(2)}x',
                      onChanged: (value) => updateSheet(
                        () => _updateSettings(steeringSensitivity: value),
                      ),
                    ),
                    _SettingsSlider(
                      label: 'Smoothing',
                      value: _smoothing,
                      min: 0.0,
                      max: 0.5,
                      divisions: 100,
                      displayValue: _smoothing.toStringAsFixed(2),
                      onChanged: (value) =>
                          updateSheet(() => _updateSettings(smoothing: value)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Invert steering'),
                      value: _invertSteering,
                      onChanged: (value) => updateSheet(
                        () => _updateSettings(invertSteering: value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => updateSheet(_resetSettingsToDefaults),
                      child: const Text('Reset to Defaults'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = switch (_connectionStatus) {
      ConnectionStatus.connecting => 'Connecting',
      ConnectionStatus.connected => 'Connected',
      ConnectionStatus.connectionLost => 'Connection lost',
      ConnectionStatus.disconnected => 'Disconnected',
    };
    final sensorText = _sensorActive ? 'Sensor active' : 'Sensor waiting';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 430;
            final pagePadding = compactHeight ? 10.0 : 16.0;
            final columnGap = compactHeight ? 10.0 : 16.0;

            return Padding(
              padding: EdgeInsets.all(pagePadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'GyroPlay',
                            style: compactHeight
                                ? Theme.of(context).textTheme.headlineSmall
                                : Theme.of(context).textTheme.headlineMedium,
                          ),
                          SizedBox(height: compactHeight ? 8 : 12),
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
                          const SizedBox(height: 8),
                          TextField(
                            controller: _pairingTokenController,
                            enabled: !_isConnected && !_isConnecting,
                            decoration: const InputDecoration(
                              labelText: 'Pairing token',
                              hintText: 'Scan QR or enter token',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('UDP port: $_pcPort'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _isConnecting || _isConnected
                                ? null
                                : _scanQrCode,
                            child: const Text('Scan QR Code'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _isConnecting
                                ? null
                                : _isConnected
                                ? _disconnect
                                : _connect,
                            child: Text(
                              _isConnected ? 'Disconnect' : 'Connect',
                            ),
                          ),
                          const SizedBox(height: 8),
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
                          OutlinedButton(
                            onPressed: _showSettingsSheet,
                            child: const Text('Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: columnGap),
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
                        Text(
                          'Raw tilt: ${_currentTiltDegrees.toStringAsFixed(1)} deg',
                        ),
                        Text(
                          'Final steering: ${_steeringValue.toStringAsFixed(3)}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          'Target: ${_targetSteeringValue.toStringAsFixed(3)}  |  5 deg -> ${_steeringFromRoll(5.0).toStringAsFixed(3)}',
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _sensorActive ? _calibrate : null,
                          child: const Text('Calibrate'),
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
                            padding: EdgeInsets.only(
                              top: compactHeight ? 8 : 16,
                            ),
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
                          onChanged: (pressed) =>
                              _setButton('handbrake', pressed),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: columnGap),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: _Pedal(
                            label: 'Brake',
                            value: _brake,
                            onChanged: (value) =>
                                _setPedalValue('brake', value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Pedal(
                            label: 'Throttle',
                            value: _throttle,
                            onChanged: (value) =>
                                _setPedalValue('throttle', value),
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

class _PairingPayload {
  const _PairingPayload({
    required this.host,
    required this.port,
    required this.pairingToken,
  });

  final String host;
  final int port;
  final String pairingToken;
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(displayValue)],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_completed) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) {
        continue;
      }

      _completed = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan GyroPlay QR')),
      body: MobileScanner(controller: _controller, onDetect: _handleDetect),
    );
  }
}
