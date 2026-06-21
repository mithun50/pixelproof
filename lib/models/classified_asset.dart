import 'package:photo_manager/photo_manager.dart';

import 'detection_result.dart';

/// A photo asset together with its (optional, once computed) detection result.
class ClassifiedAsset {
  ClassifiedAsset({required this.asset, this.result});

  /// The underlying gallery asset.
  final AssetEntity asset;

  /// Detection result, or null until classified.
  DetectionResult? result;

  String get id => asset.id;

  bool get isClassified => result != null;
}

/// High-level phase of the scanning workflow.
enum ScanPhase { idle, loadingLibrary, scanning, done, error }

/// Immutable snapshot of scan progress for the UI.
class ScanProgress {
  const ScanProgress({
    this.phase = ScanPhase.idle,
    this.processed = 0,
    this.total = 0,
    this.message = '',
  });

  final ScanPhase phase;
  final int processed;
  final int total;
  final String message;

  double get fraction => total == 0 ? 0 : processed / total;

  bool get isRunning =>
      phase == ScanPhase.loadingLibrary || phase == ScanPhase.scanning;

  ScanProgress copyWith({
    ScanPhase? phase,
    int? processed,
    int? total,
    String? message,
  }) {
    return ScanProgress(
      phase: phase ?? this.phase,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      message: message ?? this.message,
    );
  }
}
