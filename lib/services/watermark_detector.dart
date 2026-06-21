import 'dart:typed_data';

import '../models/detection_result.dart';

/// Abstraction over the Tier 2 watermark detector.
///
/// Keeping this interface free of Flutter/native imports lets the
/// [DetectionEngine] and its tests depend only on pure Dart.
abstract class WatermarkDetector {
  /// Inspects raw image [bytes] for a watermark carrier signature.
  Future<TierResult> detect(Uint8List bytes);
}
