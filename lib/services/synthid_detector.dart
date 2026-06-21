import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/detection_result.dart';
import 'spectral.dart';
import 'watermark_detector.dart';

/// Tunable parameters for the spectral detector.
class SynthIdParams {
  const SynthIdParams({
    this.analysisSize = 256,
    this.rLow = 3,
    this.rHigh = 48,
    this.fireRatio = 30.0,
    this.maxRatio = 90.0,
  });

  /// Square analysis size (power of two).
  final int analysisSize;

  /// Inner radius (bins) of the analysis annulus — excludes DC / smooth gradients.
  final int rLow;

  /// Outer radius of the analysis annulus.
  final int rHigh;

  /// Peak-to-median ratio at or above which a carrier is flagged.
  final double fireRatio;

  /// Ratio mapped to full confidence.
  final double maxRatio;
}

/// Tier 2 detector: spectral watermark-carrier detection. DETECTION ONLY.
///
/// Google's SynthID and similar spread-spectrum watermarks inject energy at
/// fixed, image-content-independent carrier frequencies. In the image's noise
/// residual spectrum these appear as **isolated periodic peaks** that natural
/// photographs (whose spectra decay smoothly) essentially never produce.
///
/// We re-implement the *detection* idea independently and conservatively:
///   green channel -> remove DC -> 2D FFT -> peak-to-median ratio in a
///   low/mid-frequency annulus. A high, isolated peak flags a likely carrier.
///
/// This is a heuristic *presence* indicator, intentionally tuned to rarely
/// false-fire. It NEVER removes, weakens, or bypasses a watermark — PixelProof
/// only detects, and never disguises AI-generated content as human-made.
class SynthIdDetector implements WatermarkDetector {
  const SynthIdDetector({
    this.params = const SynthIdParams(),
    this.enabled = false,
  });

  final SynthIdParams params;

  /// Whether the spectral tier participates in fusion.
  ///
  /// Disabled by default: a bare peak-to-median spectral test false-fires on
  /// ordinary photographs (whose natural 1/f spectra produce strong
  /// low-frequency peaks). Reliable SynthID detection needs the per-resolution
  /// carrier *phase* reference codebook; until that is integrated this tier
  /// abstains rather than mislabel real photos as AI.
  final bool enabled;

  @override
  Future<TierResult> detect(Uint8List bytes) async {
    if (!enabled) {
      return TierResult.abstain(
        DetectionSignal.synthid,
        detail: 'SynthID spectral tier disabled (needs carrier codebook).',
      );
    }
    final ratio = await compute(
      _analyze,
      _SynthIdRequest(bytes, params.analysisSize, params.rLow, params.rHigh),
    );
    if (ratio == null) {
      return TierResult.abstain(
        DetectionSignal.synthid,
        detail: 'Could not analyze spectrum.',
      );
    }
    if (ratio < params.fireRatio) {
      return TierResult.abstain(
        DetectionSignal.synthid,
        detail:
            'No watermark carrier (peak ratio ${ratio.toStringAsFixed(1)}).',
      );
    }
    final confidence = ((ratio - params.fireRatio) /
            (params.maxRatio - params.fireRatio))
        .clamp(0.0, 1.0);
    return TierResult(
      signal: DetectionSignal.synthid,
      fired: true,
      aiProbability: 0.90 + 0.09 * confidence,
      detail:
          'Periodic watermark carrier detected (peak ratio '
          '${ratio.toStringAsFixed(1)}).',
    );
  }
}

// --- Pure, testable spectral core ---

class _SynthIdRequest {
  const _SynthIdRequest(this.bytes, this.size, this.rLow, this.rHigh);
  final Uint8List bytes;
  final int size;
  final int rLow;
  final int rHigh;
}

/// Isolate entry: decode -> green plane -> resize -> [carrierPeakRatio].
double? _analyze(_SynthIdRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) return null;
  final resized =
      img.copyResize(decoded, width: req.size, height: req.size);
  final gray = Float64List(req.size * req.size);
  int i = 0;
  for (int y = 0; y < req.size; y++) {
    for (int x = 0; x < req.size; x++) {
      // Green channel carries the strongest SynthID signal (per research).
      gray[i++] = resized.getPixel(x, y).g.toDouble();
    }
  }
  return carrierPeakRatio(gray, req.size, rLow: req.rLow, rHigh: req.rHigh);
}
