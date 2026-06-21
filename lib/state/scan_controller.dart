import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/classified_asset.dart';
import '../models/detection_result.dart';
import '../services/background_scan_service.dart';
import '../services/detection_engine.dart';
import '../services/gallery_service.dart';
import '../services/permission_service.dart';
import '../services/result_cache.dart';

/// Orchestrates the end-to-end flow: permissions -> load library -> background
/// scan -> expose AI / Real / Uncertain buckets to the UI.
///
/// The heavy scan (ONNX inference) runs in a foreground-service background
/// isolate, so it continues when the app is backgrounded and never blocks the
/// UI thread. Results stream back in batches and are applied to [assets].
class ScanController extends ChangeNotifier {
  ScanController({
    required this.permissionService,
    required this.galleryService,
    required this.engine,
    required this.cache,
  });

  final PermissionService permissionService;
  final GalleryService galleryService;
  final DetectionEngine engine;
  final ResultCache cache;

  final FlutterBackgroundService _service = FlutterBackgroundService();
  StreamSubscription<Map<String, dynamic>?>? _updateSub;
  StreamSubscription<Map<String, dynamic>?>? _doneSub;

  PhotoAccess _access = PhotoAccess.denied;
  PhotoAccess get access => _access;

  ScanProgress _progress = const ScanProgress();
  ScanProgress get progress => _progress;

  final List<ClassifiedAsset> _assets = [];
  final Map<String, ClassifiedAsset> _byId = {};
  List<ClassifiedAsset> get assets => List.unmodifiable(_assets);

  List<ClassifiedAsset> get aiAssets =>
      _assets.where((a) => a.result?.verdict == Verdict.ai).toList();
  List<ClassifiedAsset> get realAssets =>
      _assets.where((a) => a.result?.verdict == Verdict.real).toList();
  List<ClassifiedAsset> get uncertainAssets =>
      _assets.where((a) => a.result?.verdict == Verdict.uncertain).toList();

  Future<PhotoAccess> requestAccess() async {
    _access = await permissionService.request();
    notifyListeners();
    return _access;
  }

  Future<PhotoAccess> refreshAccess() async {
    _access = await permissionService.current();
    notifyListeners();
    return _access;
  }

  /// Loads the photo library into [assets] (no classification yet) and applies
  /// any cached verdicts from previous scans.
  Future<void> loadLibrary() async {
    _setProgress(const ScanProgress(
      phase: ScanPhase.loadingLibrary,
      message: 'Loading photo library…',
    ));
    try {
      final entities = await galleryService.loadAllImages();
      _assets.clear();
      _byId.clear();
      for (final e in entities) {
        final ca = ClassifiedAsset(asset: e);
        _assets.add(ca);
        _byId[ca.id] = ca;
      }
      // Apply cached results so prior scans show immediately.
      for (final ca in _assets) {
        ca.result ??= await cache.get(
          ca.id,
          ca.asset.modifiedDateTime.millisecondsSinceEpoch,
        );
      }
      _setProgress(ScanProgress(
        phase: ScanPhase.idle,
        total: _assets.length,
        message: '${_assets.length} photos found',
      ));
    } catch (e) {
      _setProgress(ScanProgress(
        phase: ScanPhase.error,
        message: 'Failed to load library: $e',
      ));
    }
  }

  /// Starts the background foreground-service scan.
  Future<void> scan() async {
    if (_assets.isEmpty) await loadLibrary();

    _setProgress(ScanProgress(
      phase: ScanPhase.scanning,
      total: _assets.length,
      processed: 0,
      message: 'Starting background scan…',
    ));

    await ensureModelExtracted();
    _listen();

    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
    }
  }

  void _listen() {
    _updateSub ??= _service.on('update').listen(_onUpdate);
    _doneSub ??= _service.on('done').listen(_onDone);
  }

  void _onUpdate(Map<String, dynamic>? event) {
    if (event == null) return;
    _applyResults(event['results']);
    _setProgress(_progress.copyWith(
      phase: ScanPhase.scanning,
      processed: (event['processed'] as num?)?.toInt() ?? _progress.processed,
      total: (event['total'] as num?)?.toInt() ?? _progress.total,
      message: 'Scanning…',
    ));
  }

  void _onDone(Map<String, dynamic>? event) {
    if (event != null) _applyResults(event['results']);
    _setProgress(_progress.copyWith(
      phase: ScanPhase.done,
      processed: (event?['processed'] as num?)?.toInt() ?? _progress.processed,
      message: 'Scan complete',
    ));
  }

  void _applyResults(Object? rawResults) {
    if (rawResults is! List) return;
    for (final item in rawResults) {
      if (item is! Map) continue;
      final id = item['id'] as String?;
      if (id == null) continue;
      final ca = _byId[id];
      if (ca == null) continue;
      try {
        ca.result = DetectionResult.fromJson(Map<String, Object?>.from(item));
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Requests cancellation of an in-progress scan.
  void cancel() => _service.invoke('stopScan');

  /// Clears cached results and resets classifications.
  Future<void> resetResults() async {
    await cache.clear();
    for (final a in _assets) {
      a.result = null;
    }
    _setProgress(ScanProgress(
      phase: ScanPhase.idle,
      total: _assets.length,
    ));
  }

  void _setProgress(ScanProgress p) {
    _progress = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _doneSub?.cancel();
    super.dispose();
  }
}
