import 'dart:convert';
import 'dart:typed_data';

import 'package:pixelproof/models/detection_result.dart';
import 'package:pixelproof/services/metadata_service.dart';
import 'package:test/test.dart';

void main() {
  const service = MetadataService();

  test('fires on an AI generator signature in metadata text', () async {
    final bytes = Uint8List.fromList(
        utf8.encode('....Software: Midjourney v6 ....random padding'));
    final r = await service.inspect(bytes);
    expect(r.fired, isTrue);
    expect(r.signal, DetectionSignal.metadata);
    expect(r.aiProbability, 1.0);
  });

  test('fires on a C2PA / IPTC provenance marker', () async {
    final bytes = Uint8List.fromList(
        utf8.encode('xmp DigitalSourceType trainedAlgorithmicMedia'));
    final r = await service.inspect(bytes);
    expect(r.fired, isTrue);
  });

  test('abstains when no AI provenance markers are present', () async {
    final bytes = Uint8List.fromList(
        utf8.encode('Canon EOS 5D Mark IV  f/2.8  ISO100  ordinary photo'));
    final r = await service.inspect(bytes);
    expect(r.fired, isFalse);
    expect(r.signal, DetectionSignal.metadata);
  });
}
