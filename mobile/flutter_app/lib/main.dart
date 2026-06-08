import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const GyroPlayApp());
}

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

class _GyroPlayHomeState extends State<GyroPlayHome> {
  static const int _udpPort = 5005;

  final TextEditingController _ipController = TextEditingController();

  RawDatagramSocket? _socket;
  InternetAddress? _pcAddress;
  double _leftX = 0.0;
  bool _isConnecting = false;

  bool get _isConnected => _socket != null;

  @override
  void dispose() {
    _sendSteering(0.0);
    _socket?.close();
    _ipController.dispose();
    super.dispose();
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

      _sendSteering(_leftX);
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
    _sendSteering(0.0);
    _socket?.close();

    setState(() {
      _socket = null;
      _pcAddress = null;
      _leftX = 0.0;
    });

    _showSnackBar('Disconnected.');
  }

  void _sendSteering(double leftX) {
    final socket = _socket;
    final address = _pcAddress;

    if (socket == null || address == null) {
      return;
    }

    final packet = jsonEncode({'type': 'gamepad_update', 'left_x': leftX});

    try {
      socket.send(utf8.encode(packet), address, _udpPort);
    } on SocketException catch (error) {
      _showSnackBar('Socket error: ${error.message}');
    } catch (error) {
      _showSnackBar('Failed to send packet: $error');
    }
  }

  void _onSteeringChanged(double value) {
    setState(() {
      _leftX = value;
    });

    if (_isConnected) {
      _sendSteering(value);
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

    return Scaffold(
      appBar: AppBar(title: const Text('GyroPlay'), centerTitle: false),
      body: SafeArea(
        child: Padding(
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
              Text(statusText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 32),
              Text('Steering', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _leftX.toStringAsFixed(2),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Slider(
                value: _leftX,
                min: -1.0,
                max: 1.0,
                divisions: 200,
                label: _leftX.toStringAsFixed(2),
                onChanged: _onSteeringChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
