import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/detection_result.dart';
import '../state/scan_controller.dart';
import '../widgets/confidence_badge.dart';

/// Lets the user pick a single image and check it on demand.
class ManualCheckScreen extends StatefulWidget {
  const ManualCheckScreen({super.key});

  @override
  State<ManualCheckScreen> createState() => _ManualCheckScreenState();
}

class _ManualCheckScreenState extends State<ManualCheckScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;
  String? _path;
  DetectionResult? _result;
  bool _busy = false;
  String? _error;

  Future<void> _pickAndCheck(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _bytes = null;
    });
    try {
      final engine = context.read<ScanController>().engine;
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      await engine.init();
      final result = await engine.analyze(bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _path = file.path;
        _result = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not analyze image: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Check an image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick a single image to check whether it looks AI-generated or '
              'real. Analysis runs on-device.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _bytes != null
                    ? Image.memory(_bytes!, fit: BoxFit.contain)
                    : (_path != null
                        ? Image.file(File(_path!), fit: BoxFit.contain)
                        : Center(
                            child: Icon(Icons.image_outlined,
                                size: 64, color: theme.colorScheme.outline),
                          )),
              ),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            if (_result != null) _ResultCard(result: _result!),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickAndCheck(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Pick from gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => _pickAndCheck(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = VerdictColors.of(result.verdict);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(VerdictColors.iconOf(result.verdict), color: color),
                const SizedBox(width: 8),
                Text(result.verdict.label,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${result.confidencePercent} confidence'),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.reason),
            const SizedBox(height: 4),
            Text('Decided by: ${result.decidingSignal.displayName}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            if (result.tiers.isNotEmpty) ...[
              const Divider(height: 24),
              ...result.tiers.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          t.fired
                              ? Icons.check_circle
                              : Icons.remove_circle_outline,
                          size: 16,
                          color: t.fired
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t.signal.displayName)),
                        if (t.aiProbability != null)
                          Text('${(t.aiProbability! * 100).round()}% AI',
                              style: theme.textTheme.bodySmall),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
