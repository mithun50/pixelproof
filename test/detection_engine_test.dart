import 'dart:typed_data';

import 'package:pixelproof/models/detection_result.dart';
import 'package:pixelproof/services/ai_classifier.dart';
import 'package:pixelproof/services/detection_engine.dart';
import 'package:pixelproof/services/metadata_service.dart';
import 'package:pixelproof/services/watermark_detector.dart';
import 'package:test/test.dart';

/// Fake metadata tier with a configurable result.
class _FakeMetadata extends MetadataService {
  const _FakeMetadata(this._result);
  final TierResult _result;
  @override
  Future<TierResult> inspect(Uint8List bytes) async => _result;
}

class _FakeSynthId implements WatermarkDetector {
  const _FakeSynthId(this._result);
  final TierResult _result;
  @override
  Future<TierResult> detect(Uint8List bytes) async => _result;
}

/// Pure fake classifier — no onnxruntime dependency.
class _FakeClassifier implements AiClassifier {
  _FakeClassifier(this._result);
  final TierResult _result;
  @override
  bool get isReady => true;
  @override
  Future<void> init() async {}
  @override
  Future<TierResult> classify(Uint8List bytes) async => _result;
}

DetectionEngine engineWith({
  required TierResult meta,
  required TierResult synth,
  required TierResult neural,
}) {
  return DetectionEngine(
    metadata: _FakeMetadata(meta),
    synthid: _FakeSynthId(synth),
    classifier: _FakeClassifier(neural),
  );
}

void main() {
  final bytes = Uint8List(0);
  final abstainMeta = TierResult.abstain(DetectionSignal.metadata);
  final abstainSynth = TierResult.abstain(DetectionSignal.synthid);

  test('metadata tier overrides everything when it fires', () async {
    final engine = engineWith(
      meta: const TierResult(
          signal: DetectionSignal.metadata, fired: true, aiProbability: 1.0),
      synth: abstainSynth,
      neural: const TierResult(
          signal: DetectionSignal.neural, fired: true, aiProbability: 0.1),
    );
    final r = await engine.analyze(bytes);
    expect(r.verdict, Verdict.ai);
    expect(r.decidingSignal, DetectionSignal.metadata);
    expect(r.confidence, greaterThan(0.9));
  });

  test('SynthID tier decides when metadata abstains', () async {
    final engine = engineWith(
      meta: abstainMeta,
      synth: const TierResult(
          signal: DetectionSignal.synthid, fired: true, aiProbability: 0.97),
      neural: const TierResult(
          signal: DetectionSignal.neural, fired: true, aiProbability: 0.2),
    );
    final r = await engine.analyze(bytes);
    expect(r.verdict, Verdict.ai);
    expect(r.decidingSignal, DetectionSignal.synthid);
  });

  test('neural high probability => AI', () async {
    final engine = engineWith(
      meta: abstainMeta,
      synth: abstainSynth,
      neural: const TierResult(
          signal: DetectionSignal.neural, fired: true, aiProbability: 0.88),
    );
    final r = await engine.analyze(bytes);
    expect(r.verdict, Verdict.ai);
    expect(r.decidingSignal, DetectionSignal.neural);
    expect(r.confidence, closeTo(0.88, 1e-9));
  });

  test('neural low probability => Real', () async {
    final engine = engineWith(
      meta: abstainMeta,
      synth: abstainSynth,
      neural: const TierResult(
          signal: DetectionSignal.neural, fired: true, aiProbability: 0.12),
    );
    final r = await engine.analyze(bytes);
    expect(r.verdict, Verdict.real);
    expect(r.confidence, closeTo(0.88, 1e-9));
  });

  test('neural mid probability => uncertain', () async {
    final engine = engineWith(
      meta: abstainMeta,
      synth: abstainSynth,
      neural: const TierResult(
          signal: DetectionSignal.neural, fired: true, aiProbability: 0.5),
    );
    final r = await engine.analyze(bytes);
    expect(r.verdict, Verdict.uncertain);
  });

  test('all tiers abstain => uncertain with no signal', () async {
    final engine = engineWith(
      meta: abstainMeta,
      synth: abstainSynth,
      neural: TierResult.abstain(DetectionSignal.neural),
    );
    final r = await engine.analyze(bytes);
    expect(r.verdict, Verdict.uncertain);
    expect(r.decidingSignal, DetectionSignal.none);
  });
}
