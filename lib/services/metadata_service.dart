import 'dart:typed_data';

import 'package:exif/exif.dart';

import '../models/detection_result.dart';

/// Tier 1 detector: provenance via EXIF / XMP / C2PA metadata.
///
/// Many AI tools leave readable provenance signatures:
///   * C2PA / Content Credentials (`c2pa`, `claim_generator`, `contentauth`)
///   * IPTC `DigitalSourceType` = `trainedAlgorithmicMedia` (the standard AI tag)
///   * XMP / EXIF `Software` tags ("Stable Diffusion", "Midjourney", "DALL-E",
///     "Adobe Firefly", "Gemini", "Imagen", "Flux", ...)
///
/// When such a marker is present the verdict is near-certain. Otherwise the
/// tier abstains so lower tiers decide. Reading metadata is cheap and runs
/// before the expensive neural pass.
class MetadataService {
  const MetadataService();

  /// Tool/signature substrings that strongly indicate AI generation.
  static const List<String> _aiGenerators = [
    'stable diffusion',
    'stablediffusion',
    'midjourney',
    'dall-e',
    'dalle',
    'openai',
    'adobe firefly',
    'firefly',
    'gemini',
    'imagen',
    'flux',
    'leonardo.ai',
    'nightcafe',
    'dreamstudio',
    'playground ai',
    'novelai',
    'comfyui',
    'automatic1111',
    'invokeai',
  ];

  /// Standardized AI provenance markers (C2PA / IPTC).
  static const List<String> _provenanceMarkers = [
    'trainedalgorithmicmedia', // IPTC DigitalSourceType for AI
    'compositewithtrainedalgorithmicmedia',
    'algorithmicmedia',
    'c2pa',
    'contentauth',
    'claim_generator',
    'genai',
    'generativeai',
  ];

  Future<TierResult> inspect(Uint8List bytes) async {
    final hits = <String>{};

    // 1) Structured EXIF/XMP via the exif package.
    try {
      final tags = await readExifFromBytes(bytes);
      for (final entry in tags.entries) {
        final value = entry.value.printable.toLowerCase();
        _scan(value, hits);
        // Software / ProcessingSoftware / HostComputer tags are most telling.
      }
    } catch (_) {
      // Not all images have parseable EXIF; ignore.
    }

    // 2) Raw scan for XMP / C2PA markers that the EXIF parser may not expose.
    //    XMP is embedded as readable text; C2PA manifests reference c2pa/jumbf.
    final text = _asciiWindow(bytes);
    _scan(text, hits);

    if (hits.isEmpty) {
      return TierResult.abstain(
        DetectionSignal.metadata,
        detail: 'No AI provenance markers in metadata.',
      );
    }

    final label = hits.first;
    return TierResult(
      signal: DetectionSignal.metadata,
      fired: true,
      aiProbability: 1.0,
      detail: 'Provenance marker found: "$label".',
    );
  }

  void _scan(String haystack, Set<String> hits) {
    if (haystack.isEmpty) return;
    for (final m in _provenanceMarkers) {
      if (haystack.contains(m)) hits.add(m);
    }
    for (final g in _aiGenerators) {
      if (haystack.contains(g)) hits.add(g);
    }
  }

  /// Extracts printable ASCII from the (bounded) head of the file where XMP /
  /// metadata blocks live, to scan for textual markers cheaply.
  String _asciiWindow(Uint8List bytes, {int maxBytes = 262144}) {
    final n = bytes.length < maxBytes ? bytes.length : maxBytes;
    final sb = StringBuffer();
    for (int i = 0; i < n; i++) {
      final b = bytes[i];
      // Printable ASCII range; collapse others to spaces.
      sb.writeCharCode((b >= 0x20 && b < 0x7f) ? b : 0x20);
    }
    return sb.toString().toLowerCase();
  }
}
