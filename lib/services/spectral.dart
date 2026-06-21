import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// Peak-to-median magnitude ratio in a frequency annulus of a real [size]x[size]
/// field. High values indicate an isolated periodic carrier — the spectral
/// signature spread-spectrum watermarks (such as SynthID) rely on.
///
/// Pure function (no Flutter / native deps) — unit-tested directly with
/// synthetic signals.
double carrierPeakRatio(
  Float64List field,
  int size, {
  int rLow = 3,
  int rHigh = 48,
}) {
  // Remove DC so smooth brightness doesn't dominate.
  double mean = 0;
  for (final v in field) {
    mean += v;
  }
  mean /= field.length;
  final centered = Float64List(field.length);
  for (int i = 0; i < field.length; i++) {
    centered[i] = field[i] - mean;
  }

  final (re, im) = Fft.fft2dReal(centered, size);

  final mags = <double>[];
  double peak = 0;
  final r2Low = rLow * rLow;
  final r2High = rHigh * rHigh;
  for (int y = 0; y < size; y++) {
    final fy = y <= size ~/ 2 ? y : y - size;
    for (int x = 0; x < size; x++) {
      final fx = x <= size ~/ 2 ? x : x - size;
      final r2 = fy * fy + fx * fx;
      if (r2 < r2Low || r2 > r2High) continue;
      final idx = y * size + x;
      final m = math.sqrt(re[idx] * re[idx] + im[idx] * im[idx]);
      mags.add(m);
      if (m > peak) peak = m;
    }
  }
  if (mags.isEmpty) return 0;
  mags.sort();
  final median = mags[mags.length ~/ 2];
  if (median <= 1e-9) {
    // A peak standing over an essentially empty background is a maximally
    // isolated carrier — report a large ratio rather than dividing by ~0.
    return peak > 1e-9 ? 1000.0 : 0.0;
  }
  return peak / median;
}
