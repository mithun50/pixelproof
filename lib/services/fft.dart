import 'dart:math' as math;
import 'dart:typed_data';

/// Minimal radix-2 Cooley–Tukey FFT for power-of-two lengths.
///
/// Pure Dart (no native deps) so it runs in unit tests and background isolates.
class Fft {
  /// In-place iterative radix-2 FFT. [re]/[im] length must be a power of two.
  /// [inverse] performs the inverse transform (without 1/N scaling).
  static void transform(Float64List re, Float64List im, {bool inverse = false}) {
    final n = re.length;
    if (n <= 1) return;
    assert((n & (n - 1)) == 0, 'FFT length must be a power of two');

    // Bit-reversal permutation.
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }

    final sign = inverse ? 1.0 : -1.0;
    for (int len = 2; len <= n; len <<= 1) {
      final ang = sign * 2 * math.pi / len;
      final wReal = math.cos(ang);
      final wImag = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double curReal = 1.0;
        double curImag = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final aRe = re[i + k];
          final aIm = im[i + k];
          final bRe = re[i + k + len ~/ 2];
          final bIm = im[i + k + len ~/ 2];
          final tRe = bRe * curReal - bIm * curImag;
          final tIm = bRe * curImag + bIm * curReal;
          re[i + k] = aRe + tRe;
          im[i + k] = aIm + tIm;
          re[i + k + len ~/ 2] = aRe - tRe;
          im[i + k + len ~/ 2] = aIm - tIm;
          final nextReal = curReal * wReal - curImag * wImag;
          curImag = curReal * wImag + curImag * wReal;
          curReal = nextReal;
        }
      }
    }
  }

  /// Forward 2D FFT of a real [size]x[size] matrix given row-major in [data].
  /// Returns (real, imag) row-major matrices of the same length.
  static (Float64List, Float64List) fft2dReal(Float64List data, int size) {
    final re = Float64List.fromList(data);
    final im = Float64List(data.length);

    final rowRe = Float64List(size);
    final rowIm = Float64List(size);
    // FFT over rows.
    for (int y = 0; y < size; y++) {
      final off = y * size;
      for (int x = 0; x < size; x++) {
        rowRe[x] = re[off + x];
        rowIm[x] = im[off + x];
      }
      transform(rowRe, rowIm);
      for (int x = 0; x < size; x++) {
        re[off + x] = rowRe[x];
        im[off + x] = rowIm[x];
      }
    }

    final colRe = Float64List(size);
    final colIm = Float64List(size);
    // FFT over columns.
    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        colRe[y] = re[y * size + x];
        colIm[y] = im[y * size + x];
      }
      transform(colRe, colIm);
      for (int y = 0; y < size; y++) {
        re[y * size + x] = colRe[y];
        im[y * size + x] = colIm[y];
      }
    }
    return (re, im);
  }
}
