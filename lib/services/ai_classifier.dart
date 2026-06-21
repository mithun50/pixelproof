import 'dart:typed_data';

import '../models/detection_result.dart';

/// Abstraction over the Tier 3 neural classifier.
///
/// Keeping this interface free of the `onnxruntime` import lets the
/// [DetectionEngine] — and its tests — depend only on pure Dart, so unit tests
/// run without building native assets.
abstract class AiClassifier {
  /// Loads the model (no-op if already loaded). Safe to call repeatedly.
  Future<void> init();

  /// True when inference is possible.
  bool get isReady;

  /// Classifies raw image [bytes] into a Tier 3 [TierResult].
  Future<TierResult> classify(Uint8List bytes);
}
