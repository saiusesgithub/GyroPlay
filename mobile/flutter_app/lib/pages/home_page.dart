import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../widgets/app_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.appState,
    required this.onPair,
    required this.onOpenController,
  });

  final AppState appState;
  final VoidCallback onPair;
  final VoidCallback onOpenController;

  @override
  Widget build(BuildContext context) {
    final status = switch (appState.connectionStatus) {
      ConnectionStatus.connecting => ('Connecting', Icons.sync, Colors.amber),
      ConnectionStatus.connected => ('Connected', Icons.check_circle, Colors.tealAccent),
      ConnectionStatus.connectionLost => ('Connection lost', Icons.wifi_off, Colors.orangeAccent),
      ConnectionStatus.disconnected => ('Not connected', Icons.link_off, Colors.grey),
    };

    return PageScaffold(
      title: 'GyroPlay',
      subtitle: 'Use your phone as a racing controller for your PC.',
      children: [
        const AppCard(
          child: Row(
            children: [
              BrandIcon(size: 58),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Local wireless control for sim racing.',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(icon: status.$2, label: status.$1, color: status.$3),
              const SizedBox(height: 16),
              Text(
                appState.isConnected
                    ? 'Connected to ${appState.connectedPcLabel ?? appState.ipController.text}'
                    : 'Pair with GyroPlay Desktop to start driving.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (appState.lastFriendlyError != null) ...[
                const SizedBox(height: 8),
                Text(
                  appState.lastFriendlyError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: appState.isConnected ? onOpenController : onPair,
                icon: Icon(appState.isConnected
                    ? Icons.sports_esports
                    : Icons.qr_code_scanner),
                label: Text(appState.isConnected
                    ? 'Open Controller'
                    : 'Pair a PC'),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active profile', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(appState.activeProfile.name),
              Text(
                appState.activeProfile.steeringStyle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent connection', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                appState.lastConnectedAt == null
                    ? 'No successful connection yet.'
                    : 'Last connected to ${appState.connectedPcLabel ?? appState.settings.preferredPc}.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
