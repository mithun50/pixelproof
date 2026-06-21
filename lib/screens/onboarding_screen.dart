import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/permission_service.dart';
import '../state/scan_controller.dart';
import 'home_screen.dart';

/// First-run screen that explains why access is needed and requests it.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    final controller = context.read<ScanController>();
    final access = await controller.requestAccess();
    if (!context.mounted) return;
    if (access == PhotoAccess.full || access == PhotoAccess.limited) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showDeniedDialog(context, controller);
    }
  }

  void _showDeniedDialog(BuildContext context, ScanController controller) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Photo access needed'),
        content: const Text(
          'PixelProof needs photo access to scan and sort your images. '
          'Your photos are analyzed on-device and never uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.permissionService.openSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Image.asset('assets/branding/logo.png', height: 110),
              const SizedBox(height: 16),
              Text('PixelProof',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Sort your photos into AI-generated and real — entirely '
                'on your device.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const _Bullet(
                icon: Icons.lock_outline,
                text: 'Private: images are analyzed on-device, never uploaded.',
              ),
              const _Bullet(
                icon: Icons.layers_outlined,
                text:
                    'Multi-signal: metadata, SynthID watermark, and a neural '
                    'classifier.',
              ),
              const _Bullet(
                icon: Icons.percent_outlined,
                text: 'Honest: every verdict shows a confidence score.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _continue(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Grant photo access'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Detection is probabilistic and not 100% accurate. '
                'Use results as guidance.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
