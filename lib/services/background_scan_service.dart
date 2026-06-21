import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/detection_result.dart';
import 'classifier_service.dart';
import 'detection_engine.dart';
import 'gallery_service.dart';
import 'metadata_service.dart';
import 'notification_service.dart';
import 'result_cache.dart';
import 'synthid_detector.dart';

/// How many images to process before pushing a UI/notification update.
const int kScanBatchSize = 16;

/// Resolves the on-disk model path (writable, reachable from any isolate).
Future<String> backgroundModelPath() async {
  final dir = await getDatabasesPath();
  return p.join(dir, 'model.onnx');
}

/// Copies the bundled model asset to a file so the background isolate (which
/// has no asset binary messenger) can load it. Call from the UI isolate.
Future<void> ensureModelExtracted() async {
  final path = await backgroundModelPath();
  final file = File(path);
  if (await file.exists() && await file.length() > 1000000) return;
  try {
    final data = await rootBundle.load('assets/models/model.onnx');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  } catch (_) {
    // Asset missing — background scan will run without the neural tier.
  }
}

/// Configures the background service. Call once at startup.
Future<void> configureBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onScanServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: NotificationService.channelId,
      initialNotificationTitle: 'PixelProof',
      initialNotificationContent: 'Preparing scan…',
      foregroundServiceNotificationId: 888,
      // Required on Android 14+: passed to startForeground at runtime.
      foregroundServiceTypes: const [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onScanServiceStart,
      onBackground: _onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;

bool _cancelRequested = false;

/// Background isolate entry point: runs the full batched scan.
@pragma('vm:entry-point')
Future<void> onScanServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _cancelRequested = false;

  service.on('stopScan').listen((_) => _cancelRequested = true);

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  final engine = DetectionEngine(
    metadata: const MetadataService(),
    synthid: const SynthIdDetector(), // disabled by default
    classifier:
        ClassifierService(config: ClassifierConfig(filePath: await backgroundModelPath())),
  );
  await engine.init();

  final gallery = GalleryService();
  final cache = ResultCache();

  List<dynamic> assets;
  try {
    assets = await gallery.loadAllImages();
  } catch (_) {
    assets = const [];
  }
  final total = assets.length;

  int processed = 0, ai = 0, real = 0, uncertain = 0;
  final batch = <Map<String, Object?>>[];

  Future<void> flush() async {
    service.invoke('update', {
      'processed': processed,
      'total': total,
      'ai': ai,
      'real': real,
      'uncertain': uncertain,
      'results': List<Map<String, Object?>>.from(batch),
    });
    batch.clear();
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Scanning your library',
        content: 'Analyzed $processed of $total',
      );
    }
  }

  for (final asset in assets) {
    if (_cancelRequested) break;
    try {
      final modified = asset.modifiedDateTime.millisecondsSinceEpoch;
      DetectionResult? r = await cache.get(asset.id, modified);
      if (r == null) {
        final bytes = await gallery.bytesForInference(asset);
        if (bytes != null) {
          r = await engine.analyze(bytes);
          await cache.put(asset.id, modified, r);
        }
      }
      if (r != null) {
        switch (r.verdict) {
          case Verdict.ai:
            ai++;
          case Verdict.real:
            real++;
          case Verdict.uncertain:
            uncertain++;
        }
        batch.add({'id': asset.id, ...r.toJson()});
      }
    } catch (_) {
      // Skip problem images.
    }
    processed++;
    if (batch.length >= kScanBatchSize || processed == total) {
      await flush();
    }
  }

  service.invoke('done', {
    'processed': processed,
    'total': total,
    'ai': ai,
    'real': real,
    'uncertain': uncertain,
  });

  try {
    await NotificationService.instance.init();
    await NotificationService.instance
        .showComplete(ai: ai, real: real, uncertain: uncertain);
  } catch (_) {}

  await service.stopSelf();
}
