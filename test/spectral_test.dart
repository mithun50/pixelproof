import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelproof/services/spectral.dart';
import 'package:test/test.dart';

const int size = 64;

Float64List _flat(double value) =>
    Float64List(size * size)..fillRange(0, size * size, value);

Float64List _sine(double freqY, double freqX, {double amp = 40}) {
  final f = Float64List(size * size);
  int i = 0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      f[i++] = 128 +
          amp *
              math.sin(2 * math.pi * (freqY * y + freqX * x) / size);
    }
  }
  return f;
}

Float64List _noise(int seed) {
  final rng = math.Random(seed);
  final f = Float64List(size * size);
  for (int i = 0; i < f.length; i++) {
    f[i] = 128 + (rng.nextDouble() - 0.5) * 80;
  }
  return f;
}

void main() {
  test('flat field has no carrier peak', () {
    final r = carrierPeakRatio(_flat(120), size, rHigh: 24);
    // No AC energy at all -> ratio 0.
    expect(r, lessThan(2.0));
  });

  test('injected periodic carrier produces a high isolated peak', () {
    // Frequency (6, 6) lies inside the analysis annulus.
    final r = carrierPeakRatio(_sine(6, 6), size, rHigh: 24);
    expect(r, greaterThan(30.0));
  });

  test('random noise does not produce an isolated peak', () {
    double maxRatio = 0;
    for (int s = 0; s < 5; s++) {
      final r = carrierPeakRatio(_noise(s), size, rHigh: 24);
      if (r > maxRatio) maxRatio = r;
    }
    // Broadband noise: peak stays close to the median background.
    expect(maxRatio, lessThan(15.0));
  });

  test('carrier is clearly separable from noise', () {
    final carrier = carrierPeakRatio(_sine(5, 7), size, rHigh: 24);
    final noise = carrierPeakRatio(_noise(42), size, rHigh: 24);
    expect(carrier, greaterThan(noise * 3));
  });
}
