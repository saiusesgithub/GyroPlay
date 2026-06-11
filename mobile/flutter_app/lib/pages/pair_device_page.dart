import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../widgets/app_widgets.dart';
import 'qr_scanner_page.dart';

class PairDevicePage extends StatelessWidget {
  const PairDevicePage({super.key, required this.appState});

  final AppState appState;

  Future<void> _scan(BuildContext context) async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (payload == null || !context.mounted) return;

    try {
      final pairing = appState.parsePairingPayload(payload);
      await appState.connectFromPairing(pairing);
      if (!context.mounted) return;
    } on FormatException catch (error) {
      if (!context.mounted) return;
      _show(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      _show(context, 'Invalid QR code.');
    }
  }

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final connecting = appState.connectionStatus == ConnectionStatus.connecting;

    return PageScaffold(
      title: 'Pair Device',
      subtitle: 'Connect to GyroPlay Desktop on the same Wi-Fi network.',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandIcon(size: 64),
              const SizedBox(height: 12),
              Text(
                'Scan the QR code shown in GyroPlay Desktop.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: connecting ? null : () => _scan(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Manual pairing', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: appState.ipController,
                enabled: !appState.isConnected && !connecting,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'PC IPv4 address',
                  hintText: '192.168.1.20',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: appState.tokenController,
                enabled: !appState.isConnected && !connecting,
                decoration: const InputDecoration(
                  labelText: 'Pairing code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: connecting
                    ? null
                    : appState.isConnected
                        ? appState.disconnect
                        : appState.connectManual,
                child: Text(appState.isConnected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        ),
        if (connecting)
          const AppCard(
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Waiting for the desktop to confirm pairing...')),
              ],
            ),
          ),
        if (appState.lastFriendlyError != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  appState.lastFriendlyError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: connecting ? null : appState.connectManual,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
