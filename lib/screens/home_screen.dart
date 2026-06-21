import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/classified_asset.dart';
import '../state/scan_controller.dart';
import '../widgets/asset_tile.dart';
import 'detail_sheet.dart';
import 'manual_check_screen.dart';

/// Main screen: scan controls, progress, and AI / Real / Uncertain tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanController>().loadLibrary();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScanController>();
    final progress = controller.progress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PixelProof'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'AI (${controller.aiAssets.length})'),
            Tab(text: 'Real (${controller.realAssets.length})'),
            Tab(text: 'Uncertain (${controller.uncertainAssets.length})'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Check a single image',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManualCheckScreen()),
            ),
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
          IconButton(
            tooltip: 'Reset results',
            onPressed: progress.isRunning ? null : controller.resetResults,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (progress.isRunning || progress.message.isNotEmpty)
            _ProgressBanner(controller: controller),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _Grid(items: controller.aiAssets, emptyLabel: 'No AI images'),
                _Grid(
                    items: controller.realAssets, emptyLabel: 'No real images'),
                _Grid(
                    items: controller.uncertainAssets,
                    emptyLabel: 'Nothing uncertain'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: progress.isRunning
          ? FloatingActionButton.extended(
              onPressed: controller.cancel,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            )
          : FloatingActionButton.extended(
              onPressed: controller.scan,
              icon: const Icon(Icons.search),
              label: const Text('Scan'),
            ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.controller});

  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.progress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.message, style: Theme.of(context).textTheme.bodySmall),
          if (p.isRunning) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: p.total == 0 ? null : p.fraction),
          ],
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.emptyLabel});

  final List<ClassifiedAsset> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                )),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => AssetTile(
        item: items[i],
        onTap: () => DetailSheet.show(context, items[i]),
      ),
    );
  }
}
