import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_state.dart';
import '../widgets/app_widgets.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'About',
      subtitle: 'Open-source mobile-to-PC controller.',
      children: [
        AppCard(
          child: Column(
            children: [
              const BrandIcon(size: 92),
              const SizedBox(height: 16),
              Text('GyroPlay', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Version $_version'),
              const SizedBox(height: 12),
              const Text(
                'GyroPlay turns an Android phone into a wireless racing controller for a Windows PC using local-network UDP.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('GitHub'),
                onTap: () => _open('https://github.com/saiusesgithub/GyroPlay'),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('License'),
                onTap: () => _open('https://github.com/saiusesgithub/GyroPlay/blob/main/LICENSE'),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Troubleshooting'),
                onTap: () => _open('https://github.com/saiusesgithub/GyroPlay/blob/main/docs/troubleshooting.md'),
              ),
            ],
          ),
        ),
        const AppCard(
          child: Text(
            'Acknowledgements: Flutter, sensors_plus, mobile_scanner, shared_preferences, package_info_plus, url_launcher, and the GyroPlay open-source contributors.',
          ),
        ),
      ],
    );
  }
}
