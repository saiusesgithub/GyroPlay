import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { disconnected, connecting, connected, connectionLost }

enum SteeringMode { tilt, manual }

enum AppThemeMode { system, dark, light }

class ControllerSettings {
  ControllerSettings({
    this.deadZoneDegrees = 2.0,
    this.maxTiltDegrees = 45.0,
    this.sensitivity = 1.0,
    this.smoothing = 0.12,
    this.invertSteering = false,
    this.preferredPc = '',
    this.reconnectAutomatically = true,
    this.haptics = true,
    this.keepScreenAwake = true,
    this.themeMode = AppThemeMode.dark,
  });

  double deadZoneDegrees;
  double maxTiltDegrees;
  double sensitivity;
  double smoothing;
  bool invertSteering;
  String preferredPc;
  bool reconnectAutomatically;
  bool haptics;
  bool keepScreenAwake;
  AppThemeMode themeMode;

  static ControllerSettings defaults() => ControllerSettings();
}

class ControllerProfile {
  const ControllerProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.steeringStyle,
    required this.builtIn,
  });

  final String id;
  final String name;
  final String description;
  final String steeringStyle;
  final bool builtIn;
}

class PairingPayload {
  const PairingPayload({
    required this.host,
    required this.port,
    required this.pairingToken,
  });

  final String host;
  final int port;
  final String pairingToken;
}

class AppState extends ChangeNotifier {
  static const int defaultUdpPort = 5005;
  static const Duration _sendInterval = Duration(milliseconds: 16);
  static const Duration _uiTiltInterval = Duration(milliseconds: 40);

  final ControllerSettings settings = ControllerSettings.defaults();
  final TextEditingController ipController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();
  final Stopwatch _uiTiltStopwatch = Stopwatch()..start();

  RawDatagramSocket? _socket;
  InternetAddress? _pcAddress;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Timer? _sendTimer;
  Timer? _heartbeatTimer;
  Timer? _connectTimeoutTimer;

  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  SteeringMode steeringMode = SteeringMode.tilt;
  String? sessionId;
  int pcPort = defaultUdpPort;
  double manualLeftX = 0.0;
  double steeringValue = 0.0;
  double currentTiltDegrees = 0.0;
  double targetSteeringValue = 0.0;
  double throttle = 0.0;
  double brake = 0.0;
  double rawRollDegrees = 0.0;
  double? calibratedRollDegrees;
  bool gearUp = false;
  bool gearDown = false;
  bool handbrake = false;
  bool sensorActive = false;
  bool controllerModeActive = false;
  String? lastFriendlyError;
  String? connectedPcLabel;
  DateTime? lastConnectedAt;
  String activeProfileId = 'assetto_corsa';

  List<ControllerProfile> profiles = const [
    ControllerProfile(
      id: 'assetto_corsa',
      name: 'Assetto Corsa',
      description: 'Balanced tilt steering for sim racing.',
      steeringStyle: 'Tilt wheel, 45 degree full lock',
      builtIn: true,
    ),
  ];

  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  bool get isConnecting => connectionStatus == ConnectionStatus.connecting;
  ControllerProfile get activeProfile =>
      profiles.firstWhere((profile) => profile.id == activeProfileId);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    settings.deadZoneDegrees =
        prefs.getDouble('steering_dead_zone') ?? settings.deadZoneDegrees;
    settings.maxTiltDegrees =
        prefs.getDouble('steering_max_tilt') ?? settings.maxTiltDegrees;
    settings.sensitivity =
        prefs.getDouble('steering_sensitivity') ?? settings.sensitivity;
    settings.smoothing =
        prefs.getDouble('steering_smoothing') ?? settings.smoothing;
    settings.invertSteering =
        prefs.getBool('steering_invert') ?? settings.invertSteering;
    settings.preferredPc =
        prefs.getString('preferred_pc') ?? settings.preferredPc;
    settings.reconnectAutomatically =
        prefs.getBool('reconnect_automatically') ??
            settings.reconnectAutomatically;
    settings.haptics = prefs.getBool('haptics') ?? settings.haptics;
    settings.keepScreenAwake =
        prefs.getBool('keep_screen_awake') ?? settings.keepScreenAwake;
    settings.themeMode =
        AppThemeMode.values[prefs.getInt('theme_mode') ?? 1];
    activeProfileId = prefs.getString('active_profile') ?? activeProfileId;
    ipController.text = settings.preferredPc;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('steering_dead_zone', settings.deadZoneDegrees);
    await prefs.setDouble('steering_max_tilt', settings.maxTiltDegrees);
    await prefs.setDouble('steering_sensitivity', settings.sensitivity);
    await prefs.setDouble('steering_smoothing', settings.smoothing);
    await prefs.setBool('steering_invert', settings.invertSteering);
    await prefs.setString('preferred_pc', settings.preferredPc);
    await prefs.setBool(
      'reconnect_automatically',
      settings.reconnectAutomatically,
    );
    await prefs.setBool('haptics', settings.haptics);
    await prefs.setBool('keep_screen_awake', settings.keepScreenAwake);
    await prefs.setInt('theme_mode', settings.themeMode.index);
    await prefs.setString('active_profile', activeProfileId);
  }

  void startSensors() {
    _accelerometerSubscription ??=
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          _handleAccelerometerEvent,
          onError: (_) {
            sensorActive = false;
            resetControls(sendPacket: true);
            _setError('Phone motion sensors are unavailable.');
          },
          onDone: () {
            sensorActive = false;
            resetControls(sendPacket: true);
            notifyListeners();
          },
          cancelOnError: false,
        );
  }

  Future<void> connectManual() async {
    await connect(ipController.text.trim(), tokenController.text.trim(), pcPort);
  }

  Future<void> connectFromPairing(PairingPayload pairing) async {
    ipController.text = pairing.host;
    tokenController.text = pairing.pairingToken;
    pcPort = pairing.port;
    await connect(pairing.host, pairing.pairingToken, pairing.port);
  }

  Future<void> connect(String ipText, String pairingToken, int port) async {
    final address = InternetAddress.tryParse(ipText);

    if (address == null || address.type != InternetAddressType.IPv4) {
      _setError('Enter a valid PC IPv4 address.');
      return;
    }

    if (pairingToken.isEmpty) {
      _setError('Scan a QR code or enter a pairing token from GyroPlay Desktop.');
      return;
    }

    await _closeSocketOnly();
    connectionStatus = ConnectionStatus.connecting;
    sessionId = null;
    lastFriendlyError = null;
    notifyListeners();

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket = socket;
      _pcAddress = address;
      pcPort = port;
      _socketSubscription = socket.listen(_handleSocketEvent);
      _sendHello();
      _connectTimeoutTimer?.cancel();
      _connectTimeoutTimer = Timer(const Duration(seconds: 3), () {
        if (connectionStatus == ConnectionStatus.connecting) {
          markConnectionLost('No ACK received from desktop.');
        }
      });
    } on SocketException {
      connectionStatus = ConnectionStatus.disconnected;
      _setError('Network unavailable. Check Wi-Fi and try again.');
    } catch (_) {
      connectionStatus = ConnectionStatus.disconnected;
      _setError('Could not connect to the PC.');
    }
  }

  PairingPayload parsePairingPayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid QR code.');
    }

    if (decoded['version'] != 1 || decoded['type'] != 'gyroplay_pairing') {
      throw const FormatException('Invalid QR code.');
    }

    final host = decoded['host'];
    final port = decoded['port'];
    final pairingToken = decoded['pairing_token'];
    final expiresAtText = decoded['expires_at'];

    if (host is! String ||
        InternetAddress.tryParse(host)?.type != InternetAddressType.IPv4) {
      throw const FormatException('PC not found in pairing code.');
    }

    if (port is! int || port < 1 || port > 65535) {
      throw const FormatException('Invalid QR code.');
    }

    if (pairingToken is! String || pairingToken.isEmpty) {
      throw const FormatException('Invalid QR code.');
    }

    final expiresAt = expiresAtText is String
        ? DateTime.tryParse(expiresAtText)
        : null;
    if (expiresAt == null) {
      throw const FormatException('Invalid QR code.');
    }

    if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
      throw const FormatException('Pairing code expired.');
    }

    return PairingPayload(
      host: host,
      port: port,
      pairingToken: pairingToken,
    );
  }

  Future<void> disconnect() async {
    resetControls(sendPacket: true);
    await _closeSocketOnly();
    _pcAddress = null;
    sessionId = null;
    connectionStatus = ConnectionStatus.disconnected;
    connectedPcLabel = null;
    notifyListeners();
  }

  void markConnectionLost(String message) {
    resetControls(sendPacket: false);
    _closeSocketOnly();
    _pcAddress = null;
    sessionId = null;
    connectionStatus = ConnectionStatus.connectionLost;
    lastFriendlyError = message;
    notifyListeners();
  }

  Future<void> _closeSocketOnly() async {
    _sendTimer?.cancel();
    _sendTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
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
      if (packet is Map<String, dynamic> &&
          packet['version'] == 1 &&
          packet['type'] == 'hello_ack' &&
          packet['session_id'] is String) {
        _handleHelloAck(packet['session_id'] as String);
      }
    } catch (_) {
      _setError('The desktop sent an unreadable response.');
    }
  }

  void _handleHelloAck(String nextSessionId) {
    _connectTimeoutTimer?.cancel();
    sessionId = nextSessionId;
    connectionStatus = ConnectionStatus.connected;
    settings.preferredPc = ipController.text.trim();
    connectedPcLabel = '${_pcAddress?.address ?? settings.preferredPc}:$pcPort';
    lastConnectedAt = DateTime.now();
    save();
    sendControllerState();
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(_sendInterval, (_) => sendControllerState());
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sendHeartbeat(),
    );
    notifyListeners();
  }

  void setControllerModeActive(bool active) {
    controllerModeActive = active;
    notifyListeners();
  }

  void setMode(SteeringMode mode) {
    steeringMode = mode;
    manualLeftX = 0.0;
    steeringValue = 0.0;
    targetSteeringValue = 0.0;
    sendNeutralPacket();
    notifyListeners();
  }

  void selectProfile(String profileId) {
    activeProfileId = profileId;
    save();
    notifyListeners();
  }

  void updateSettings({
    double? deadZoneDegrees,
    double? maxTiltDegrees,
    double? sensitivity,
    double? smoothing,
    bool? invertSteering,
    String? preferredPc,
    bool? reconnectAutomatically,
    bool? haptics,
    bool? keepScreenAwake,
    AppThemeMode? themeMode,
  }) {
    if (deadZoneDegrees != null) settings.deadZoneDegrees = deadZoneDegrees;
    if (maxTiltDegrees != null) settings.maxTiltDegrees = maxTiltDegrees;
    if (sensitivity != null) settings.sensitivity = sensitivity;
    if (smoothing != null) settings.smoothing = smoothing;
    if (invertSteering != null) settings.invertSteering = invertSteering;
    if (preferredPc != null) {
      settings.preferredPc = preferredPc;
      ipController.text = preferredPc;
    }
    if (reconnectAutomatically != null) {
      settings.reconnectAutomatically = reconnectAutomatically;
    }
    if (haptics != null) settings.haptics = haptics;
    if (keepScreenAwake != null) settings.keepScreenAwake = keepScreenAwake;
    if (themeMode != null) settings.themeMode = themeMode;
    save();
    notifyListeners();
  }

  void resetSettingsToDefaults() {
    final defaults = ControllerSettings.defaults();
    settings.deadZoneDegrees = defaults.deadZoneDegrees;
    settings.maxTiltDegrees = defaults.maxTiltDegrees;
    settings.sensitivity = defaults.sensitivity;
    settings.smoothing = defaults.smoothing;
    settings.invertSteering = defaults.invertSteering;
    settings.reconnectAutomatically = defaults.reconnectAutomatically;
    settings.haptics = defaults.haptics;
    settings.keepScreenAwake = defaults.keepScreenAwake;
    settings.themeMode = defaults.themeMode;
    save();
    notifyListeners();
  }

  void calibrateNow() {
    calibratedRollDegrees = rawRollDegrees;
    currentTiltDegrees = 0.0;
    manualLeftX = 0.0;
    steeringValue = 0.0;
    targetSteeringValue = 0.0;
    sendNeutralPacket();
    notifyListeners();
  }

  void setManualSteering(double value) {
    manualLeftX = value;
    steeringValue = value;
    notifyListeners();
  }

  void setPedalValue(String pedal, double value) {
    final clampedValue = value.clamp(0.0, 1.0);
    if (pedal == 'throttle') {
      throttle = clampedValue;
    } else {
      brake = clampedValue;
    }
    notifyListeners();
  }

  void setButton(String button, bool isPressed) {
    if (settings.haptics && isPressed) {
      HapticFeedback.selectionClick();
    }

    if (button == 'gear_up') {
      gearUp = isPressed;
    } else if (button == 'gear_down') {
      gearDown = isPressed;
    } else {
      handbrake = isPressed;
    }
    notifyListeners();
  }

  void resetControls({required bool sendPacket}) {
    manualLeftX = 0.0;
    steeringValue = 0.0;
    targetSteeringValue = 0.0;
    throttle = 0.0;
    brake = 0.0;
    gearUp = false;
    gearDown = false;
    handbrake = false;
    if (sendPacket) {
      sendNeutralPacket();
    }
    notifyListeners();
  }

  void sendNeutralPacket() {
    sendControllerState(
      leftX: 0.0,
      throttleValue: 0.0,
      brakeValue: 0.0,
      gearUpValue: false,
      gearDownValue: false,
      handbrakeValue: false,
    );
  }

  void _sendHello() {
    final socket = _socket;
    final address = _pcAddress;
    if (socket == null || address == null) return;

    final packet = jsonEncode({
      'version': 1,
      'type': 'hello',
      'device_name': 'Android Phone',
      'pairing_token': tokenController.text.trim(),
    });

    try {
      socket.send(utf8.encode(packet), address, pcPort);
    } on SocketException {
      markConnectionLost('Network unavailable.');
    } catch (_) {
      markConnectionLost('Could not send pairing request.');
    }
  }

  void _sendHeartbeat() {
    final socket = _socket;
    final address = _pcAddress;
    final activeSession = sessionId;
    if (socket == null || address == null || activeSession == null) return;

    final packet = jsonEncode({
      'version': 1,
      'type': 'heartbeat',
      'session_id': activeSession,
    });

    try {
      socket.send(utf8.encode(packet), address, pcPort);
    } on SocketException {
      markConnectionLost('Network unavailable.');
    } catch (_) {
      markConnectionLost('Connection lost.');
    }
  }

  void sendControllerState({
    double? leftX,
    double? throttleValue,
    double? brakeValue,
    bool? gearUpValue,
    bool? gearDownValue,
    bool? handbrakeValue,
  }) {
    final socket = _socket;
    final address = _pcAddress;
    final activeSession = sessionId;
    if (socket == null || address == null || activeSession == null) return;

    final packet = jsonEncode({
      'version': 1,
      'type': 'gamepad_update',
      'session_id': activeSession,
      'left_x': (leftX ?? steeringValue).clamp(-1.0, 1.0),
      'throttle': (throttleValue ?? throttle).clamp(0.0, 1.0),
      'brake': (brakeValue ?? brake).clamp(0.0, 1.0),
      'gear_up': gearUpValue ?? gearUp,
      'gear_down': gearDownValue ?? gearDown,
      'handbrake': handbrakeValue ?? handbrake,
    });

    try {
      socket.send(utf8.encode(packet), address, pcPort);
    } on SocketException {
      markConnectionLost('Network unavailable.');
    } catch (_) {
      markConnectionLost('Connection lost.');
    }
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final rollDegrees = _landscapeRollDegrees(event);
    final centerDegrees = calibratedRollDegrees ?? rollDegrees;
    final relativeDegrees = _normalizeDegrees(rollDegrees - centerDegrees);
    final effectiveDegrees = settings.invertSteering
        ? -relativeDegrees
        : relativeDegrees;
    final targetSteering = _steeringFromRoll(effectiveDegrees);
    final smoothedSteering =
        steeringValue + settings.smoothing * (targetSteering - steeringValue);
    final shouldUpdateTiltUi = _uiTiltStopwatch.elapsed >= _uiTiltInterval;
    final steeringChanged =
        steeringMode == SteeringMode.tilt &&
        (smoothedSteering - steeringValue).abs() >= 0.001;

    if (!steeringChanged && !shouldUpdateTiltUi && sensorActive) {
      return;
    }

    sensorActive = true;
    rawRollDegrees = rollDegrees;
    calibratedRollDegrees ??= rollDegrees;
    targetSteeringValue = targetSteering;

    if (shouldUpdateTiltUi) {
      currentTiltDegrees = effectiveDegrees;
      _uiTiltStopwatch.reset();
    }

    if (steeringChanged) {
      steeringValue = smoothedSteering.clamp(-1.0, 1.0);
    }

    notifyListeners();
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
    if (rollDegrees.abs() <= settings.deadZoneDegrees) {
      return 0.0;
    }

    final adjustedDegrees = rollDegrees.abs() - settings.deadZoneDegrees;
    final steeringRange =
        (settings.maxTiltDegrees - settings.deadZoneDegrees).clamp(1.0, 90.0);
    final scaledSteering =
        (adjustedDegrees / steeringRange) * settings.sensitivity;

    return scaledSteering.clamp(0.0, 1.0) * rollDegrees.sign;
  }

  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      resetControls(sendPacket: true);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _setError(String message) {
    lastFriendlyError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    sendNeutralPacket();
    _closeSocketOnly();
    _accelerometerSubscription?.cancel();
    ipController.dispose();
    tokenController.dispose();
    super.dispose();
  }
}
