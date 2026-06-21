import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../models/detection_result.dart';
import 'ai_classifier.dart';

/// Configuration describing how to feed images to the ONNX model.
///
/// Values must match the model's `preprocessor_config.json` and `config.json`.
/// Confirmed for `onnx-community/SMOGY-Ai-images-detector-ONNX` (Swin) in
/// Task 4 when the model asset is bundled.
class ClassifierConfig {
  const ClassifierConfig({
    this.assetPath = 'assets/models/model.onnx',
    this.filePath,
    this.inputSize = 224,
    // ImageNet mean/std — confirmed from the model's preprocessor_config.json
    // (ViTFeatureExtractor: do_rescale 1/255 then normalize).
    this.mean = const [0.485, 0.456, 0.406],
    this.std = const [0.229, 0.224, 0.225],
    this.aiLabelIndex = 0,
    this.inputName,
  });

  /// Bundled model path.
  final String assetPath;

  /// Optional filesystem path to the model. When set (and the file exists) it
  /// is loaded instead of [assetPath]. Used by the background isolate, which
  /// has no asset binary messenger.
  final String? filePath;

  /// Square input edge in pixels.
  final int inputSize;

  /// Per-channel normalization mean (RGB).
  final List<double> mean;

  /// Per-channel normalization std (RGB).
  final List<double> std;

  /// Index in the logits vector corresponding to the "AI / artificial" class.
  /// Confirmed from config.json: id2label {0: "artificial", 1: "human"}.
  final int aiLabelIndex;

  /// Explicit input tensor name; if null the first session input is used.
  final String? inputName;
}

/// Tier 3 detector: an on-device ONNX Swin-transformer image classifier.
///
/// All inference runs on-device; nothing is uploaded. Preprocessing is offloaded
/// to a background isolate; the ORT session runs via [OrtSession.runAsync].
class ClassifierService implements AiClassifier {
  ClassifierService({this.config = const ClassifierConfig()});

  final ClassifierConfig config;

  OrtSession? _session;
  bool _initialized = false;

  /// True when the model is loaded and inference is possible.
  @override
  bool get isReady => _session != null;

  /// Loads the ONNX model from assets. Safe to call multiple times.
  ///
  /// If the asset is missing (e.g. before Task 4 bundles it), the service
  /// stays in a not-ready state and [classify] abstains instead of throwing.
  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      OrtEnv.instance.init();
      final Uint8List bytes;
      final fp = config.filePath;
      if (fp != null && File(fp).existsSync()) {
        bytes = await File(fp).readAsBytes();
      } else {
        final ByteData raw = await rootBundle.load(config.assetPath);
        bytes = raw.buffer.asUint8List();
      }
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
    } catch (e) {
      // Model not bundled or failed to load — abstain gracefully.
      _session = null;
      debugPrint('ClassifierService: model unavailable ($e)');
    }
  }

  /// Classifies raw image [bytes], returning a Tier 3 [TierResult].
  @override
  Future<TierResult> classify(Uint8List bytes) async {
    final OrtSession? session = _session;
    if (session == null) {
      return TierResult.abstain(
        DetectionSignal.neural,
        detail: 'Neural model not loaded.',
      );
    }

    // Preprocess off the UI thread.
    final Float32List? input = await compute(
      _preprocess,
      _PreprocessRequest(bytes, config.inputSize, config.mean, config.std),
    );
    if (input == null) {
      return TierResult.abstain(
        DetectionSignal.neural,
        detail: 'Could not decode image.',
      );
    }

    final String inputName = config.inputName ?? session.inputNames.first;
    final shape = [1, 3, config.inputSize, config.inputSize];
    final OrtValueTensor inputTensor =
        OrtValueTensor.createTensorWithDataList(input, shape);
    final runOptions = OrtRunOptions();
    try {
      // NOTE: use the synchronous run(); the package's runAsync()
      // (OrtIsolateSession) double-completes its completer under repeated calls,
      // which both corrupts results and crashes libonnxruntime (SIGSEGV).
      final outputs = session.run(runOptions, {inputName: inputTensor});
      final logits = _extractLogits(outputs);
      inputTensor.release();
      runOptions.release();
      for (final o in outputs) {
        o?.release();
      }
      if (logits == null || logits.isEmpty) {
        return TierResult.abstain(DetectionSignal.neural,
            detail: 'Empty model output.');
      }
      final probs = _softmax(logits);
      final aiProb = config.aiLabelIndex < probs.length
          ? probs[config.aiLabelIndex]
          : probs.first;
      return TierResult(
        signal: DetectionSignal.neural,
        fired: true,
        aiProbability: aiProb,
        detail:
            'Visual-artifact model: ${(aiProb * 100).toStringAsFixed(0)}% AI.',
      );
    } catch (e) {
      inputTensor.release();
      runOptions.release();
      return TierResult.abstain(DetectionSignal.neural,
          detail: 'Inference error: $e');
    }
  }

  /// Releases native resources.
  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }

  /// Extracts a flat logits vector from ORT outputs of shape [1, numClasses].
  List<double>? _extractLogits(List<OrtValue?>? outputs) {
    if (outputs == null || outputs.isEmpty) return null;
    final value = outputs.first?.value;
    if (value is List && value.isNotEmpty && value.first is List) {
      final row = (value.first as List).cast<num>();
      return row.map((e) => e.toDouble()).toList();
    }
    if (value is List && value.isNotEmpty && value.first is num) {
      return value.cast<num>().map((e) => e.toDouble()).toList();
    }
    return null;
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}

// --- Isolate-safe top-level preprocessing ---

class _PreprocessRequest {
  const _PreprocessRequest(this.bytes, this.size, this.mean, this.std);
  final Uint8List bytes;
  final int size;
  final List<double> mean;
  final List<double> std;
}

/// Decodes, resizes to [size]x[size], and normalizes into a CHW Float32List.
Float32List? _preprocess(_PreprocessRequest req) {
  final img.Image? decoded = img.decodeImage(req.bytes);
  if (decoded == null) return null;
  final img.Image resized = img.copyResize(
    decoded,
    width: req.size,
    height: req.size,
    interpolation: img.Interpolation.cubic,
  );

  final int area = req.size * req.size;
  final Float32List out = Float32List(3 * area);
  int idx = 0;
  // Channel-first (CHW): all R, then all G, then all B.
  for (int c = 0; c < 3; c++) {
    final double mean = req.mean[c];
    final double std = req.std[c];
    for (int y = 0; y < req.size; y++) {
      for (int x = 0; x < req.size; x++) {
        final img.Pixel p = resized.getPixel(x, y);
        final double channel = switch (c) {
          0 => p.r.toDouble(),
          1 => p.g.toDouble(),
          _ => p.b.toDouble(),
        };
        out[idx++] = ((channel / 255.0) - mean) / std;
      }
    }
  }
  return out;
}
