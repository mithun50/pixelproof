/// Core data models for PixelProof's tiered detection engine.
///
/// The engine combines several independent signals (tiers). Each tier produces
/// a [TierResult]; the [DetectionEngine] fuses them into a single
/// [DetectionResult] with an honest, explainable confidence.
library;

/// The final classification bucket for an image.
enum Verdict {
  /// The image is judged AI-generated.
  ai,

  /// The image is judged a real (camera/human-made) photo.
  real,

  /// The signals were too weak or conflicting to decide confidently.
  uncertain,
}

extension VerdictLabel on Verdict {
  String get label => switch (this) {
        Verdict.ai => 'AI Generated',
        Verdict.real => 'Real',
        Verdict.uncertain => 'Uncertain',
      };
}

/// Identifies which detection tier produced a signal.
enum DetectionSignal {
  /// EXIF / XMP / C2PA provenance metadata (Tier 1, near-certain).
  metadata,

  /// SynthID spectral watermark detection (Tier 2, high precision).
  synthid,

  /// Neural classifier — Swin transformer (Tier 3, broad but probabilistic).
  neural,

  /// No signal was decisive.
  none,
}

extension DetectionSignalName on DetectionSignal {
  String get displayName => switch (this) {
        DetectionSignal.metadata => 'Provenance metadata',
        DetectionSignal.synthid => 'SynthID watermark',
        DetectionSignal.neural => 'Neural classifier',
        DetectionSignal.none => 'No decisive signal',
      };
}

/// The output of a single detection tier.
class TierResult {
  const TierResult({
    required this.signal,
    required this.fired,
    this.aiProbability,
    this.detail = '',
  });

  /// Which tier this came from.
  final DetectionSignal signal;

  /// Whether this tier produced a usable/decisive signal.
  final bool fired;

  /// Probability the image is AI in `[0, 1]`, or null if the tier abstained.
  final double? aiProbability;

  /// Human-readable explanation of what this tier found.
  final String detail;

  /// A tier that abstained (no opinion).
  factory TierResult.abstain(DetectionSignal signal, {String detail = ''}) =>
      TierResult(signal: signal, fired: false, detail: detail);
}

/// The fused result for one image.
class DetectionResult {
  const DetectionResult({
    required this.verdict,
    required this.aiProbability,
    required this.confidence,
    required this.decidingSignal,
    required this.reason,
    this.tiers = const [],
  });

  /// Final bucket.
  final Verdict verdict;

  /// Fused probability the image is AI in `[0, 1]`.
  final double aiProbability;

  /// Confidence in the [verdict] in `[0, 1]`.
  final double confidence;

  /// Which tier drove the decision.
  final DetectionSignal decidingSignal;

  /// Short, user-facing explanation (e.g. "SynthID watermark detected").
  final String reason;

  /// Per-tier breakdown for the detail view.
  final List<TierResult> tiers;

  /// Confidence as a rounded percentage string, e.g. "88%".
  String get confidencePercent => '${(confidence * 100).round()}%';

  Map<String, Object?> toJson() => {
        'verdict': verdict.name,
        'aiProbability': aiProbability,
        'confidence': confidence,
        'decidingSignal': decidingSignal.name,
        'reason': reason,
      };

  factory DetectionResult.fromJson(Map<String, Object?> json) {
    return DetectionResult(
      verdict: Verdict.values.byName(json['verdict'] as String),
      aiProbability: (json['aiProbability'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      decidingSignal:
          DetectionSignal.values.byName(json['decidingSignal'] as String),
      reason: json['reason'] as String,
    );
  }
}
