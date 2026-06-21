import 'dart:typed_data';

import '../models/detection_result.dart';
import 'ai_classifier.dart';
import 'metadata_service.dart';
import 'watermark_detector.dart';

/// Fuses the tiered detectors into a single, explainable [DetectionResult].
///
/// Priority order (highest-precision first):
///   1. Metadata / C2PA provenance  — near-certain when present.
///   2. SynthID spectral watermark  — high precision (Google models).
///   3. Neural classifier           — broad coverage, probabilistic.
///
/// A higher tier that *fires* short-circuits and overrides lower tiers. When
/// only the neural tier speaks, the verdict comes from its probability with an
/// honest "uncertain" band around the decision boundary.
class DetectionEngine {
  DetectionEngine({
    required this.metadata,
    required this.synthid,
    required this.classifier,
    this.aiThreshold = 0.60,
    this.realThreshold = 0.40,
  });

  final MetadataService metadata;
  final WatermarkDetector synthid;
  final AiClassifier classifier;

  /// Neural AI-probability at or above this => AI.
  final double aiThreshold;

  /// Neural AI-probability at or below this => Real. Between the two => uncertain.
  final double realThreshold;

  Future<void> init() => classifier.init();

  /// Runs all tiers on [bytes] and fuses them.
  Future<DetectionResult> analyze(Uint8List bytes) async {
    final tiers = <TierResult>[];

    // Tier 1: metadata (cheap, near-certain).
    final meta = await metadata.inspect(bytes);
    tiers.add(meta);
    if (meta.fired) {
      return _decisive(
        aiProbability: meta.aiProbability ?? 1.0,
        confidence: 0.99,
        signal: DetectionSignal.metadata,
        reason: meta.detail.isEmpty
            ? 'AI provenance metadata found'
            : meta.detail,
        tiers: tiers,
      );
    }

    // Tier 2: SynthID watermark (high precision for Google models).
    final wm = await synthid.detect(bytes);
    tiers.add(wm);
    if (wm.fired) {
      return _decisive(
        aiProbability: wm.aiProbability ?? 0.97,
        confidence: 0.95,
        signal: DetectionSignal.synthid,
        reason: 'SynthID watermark detected',
        tiers: tiers,
      );
    }

    // Tier 3: neural classifier (probabilistic).
    final neural = await classifier.classify(bytes);
    tiers.add(neural);
    if (neural.fired && neural.aiProbability != null) {
      final p = neural.aiProbability!;
      final Verdict verdict;
      final double confidence;
      if (p >= aiThreshold) {
        verdict = Verdict.ai;
        confidence = p;
      } else if (p <= realThreshold) {
        verdict = Verdict.real;
        confidence = 1 - p;
      } else {
        verdict = Verdict.uncertain;
        // Confidence is low near the boundary; express distance from 0.5.
        confidence = 1 - (2 * (0.5 - p).abs());
      }
      return DetectionResult(
        verdict: verdict,
        aiProbability: p,
        confidence: confidence,
        decidingSignal: DetectionSignal.neural,
        reason: verdict == Verdict.uncertain
            ? 'Visual artifacts inconclusive (${(p * 100).round()}% AI)'
            : 'Visual artifacts suggest ${verdict.label.toLowerCase()} '
                '(${(p * 100).round()}% AI)',
        tiers: tiers,
      );
    }

    // Nothing decisive.
    return DetectionResult(
      verdict: Verdict.uncertain,
      aiProbability: 0.5,
      confidence: 0.0,
      decidingSignal: DetectionSignal.none,
      reason: 'No detector could analyze this image',
      tiers: tiers,
    );
  }

  DetectionResult _decisive({
    required double aiProbability,
    required double confidence,
    required DetectionSignal signal,
    required String reason,
    required List<TierResult> tiers,
  }) {
    return DetectionResult(
      verdict: aiProbability >= 0.5 ? Verdict.ai : Verdict.real,
      aiProbability: aiProbability,
      confidence: confidence,
      decidingSignal: signal,
      reason: reason,
      tiers: tiers,
    );
  }
}
