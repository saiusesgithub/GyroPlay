import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../widgets/app_widgets.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Controller Profiles',
      subtitle: 'Tune GyroPlay for each racing game.',
      children: [
        for (final profile in appState.profiles)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      profile.id == appState.activeProfileId
                          ? Icons.check_circle
                          : Icons.sports_motorsports_outlined,
                      color: profile.id == appState.activeProfileId
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (profile.builtIn)
                      const Chip(label: Text('Built-in')),
                  ],
                ),
                const SizedBox(height: 10),
                Text(profile.description),
                const SizedBox(height: 4),
                Text(
                  profile.steeringStyle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton(
                      onPressed: profile.id == appState.activeProfileId
                          ? null
                          : () => appState.selectProfile(profile.id),
                      child: const Text('Select'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showSoon(context, 'Profile editing is planned for a later v0.1.x update.'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: profile.builtIn
                          ? 'Built-in profiles cannot be deleted'
                          : 'Delete profile',
                      onPressed: profile.builtIn
                          ? null
                          : () => _showSoon(context, 'Profile deleted.'),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _showSoon(context, 'Duplicate profiles are planned for a later v0.1.x update.'),
          icon: const Icon(Icons.copy),
          label: const Text('Duplicate Active Profile'),
        ),
      ],
    );
  }

  void _showSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
