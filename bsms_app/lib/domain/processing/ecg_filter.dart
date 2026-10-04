import 'dart:math' as math;
import '../ecg_sample.dart';

/// Bandpass filter for ECG signals (0.5 Hz – 40 Hz) at 500 Hz sample rate.
///
/// Cascades a 2nd-order Butterworth high-pass (removes baseline wander) and
/// a 2nd-order Butterworth low-pass (removes high-frequency noise).
/// Coefficients are computed via the bilinear transform.
class EcgFilter {
  static const double _sampleRateHz = 500.0;

  /// Returns a filtered copy of [samples]. Timestamps are preserved unchanged.
  /// Pipeline: HP 0.5 Hz → LP 40 Hz → Notch 50 Hz.
  static List<EcgSample> bandpass(List<EcgSample> samples) {
    if (samples.isEmpty) return [];

    final raw     = samples.map((s) => s.value.toDouble()).toList();
    final hp      = _butterworth2(raw, cutoffHz: 0.5, highPass: true);
    final bp      = _butterworth2(hp,  cutoffHz: 40.0, highPass: false);
    final notched = _notch50Hz(bp);

    return List.generate(samples.length, (i) {
      return EcgSample(value: notched[i].round(), timestampMs: samples[i].timestampMs);
    });
  }

  /// 2nd-order Butterworth IIR filter using direct form II transposed.
  static List<double> _butterworth2(
    List<double> x, {
    required double cutoffHz,
    required bool highPass,
  }) {
    final k = math.tan(math.pi * cutoffHz / _sampleRateHz);
    final k2 = k * k;
    final sq2k = math.sqrt(2) * k;
    final norm = 1.0 + sq2k + k2;

    final double b0, b1, b2;
    if (highPass) {
      b0 = 1.0 / norm;
      b1 = -2.0 / norm;
      b2 = 1.0 / norm;
    } else {
      b0 = k2 / norm;
      b1 = 2.0 * k2 / norm;
      b2 = k2 / norm;
    }
    final a1 = 2.0 * (k2 - 1.0) / norm;
    final a2 = (1.0 - sq2k + k2) / norm;

    final y = List<double>.filled(x.length, 0.0);
    // Pre-warm: assume signal starts at constant x[0].
    // For a high-pass filter b0+b1+b2 = 0, so the first output is immediately 0
    // and no DC step-transient occurs. The low-pass stage receives the near-zero
    // HP output, so its zero-initialization is already correct.
    double x1 = x.isNotEmpty ? x[0] : 0.0;
    double x2 = x.isNotEmpty ? x[0] : 0.0;
    double y1 = 0, y2 = 0;
    for (int i = 0; i < x.length; i++) {
      final xi = x[i];
      final yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      y[i] = yi;
      x2 = x1; x1 = xi;
      y2 = y1; y1 = yi;
    }
    return y;
  }

  /// 2nd-order IIR notch filter at 50 Hz (power-line interference).
  /// Bandwidth ≈ 4 Hz, zeros on the unit circle at 50 Hz,
  /// poles at same angle with radius r = 1 − π·BW/fs.
  static List<double> _notch50Hz(List<double> x) {
    const double bw     = 4.0;
    final double omega0 = 2.0 * math.pi * 50.0 / _sampleRateHz;
    final double cosW0  = math.cos(omega0);
    final double r      = 1.0 - math.pi * bw / _sampleRateHz;

    // H(z) = (1 − 2cos(ω₀)z⁻¹ + z⁻²) / (1 − 2r·cos(ω₀)z⁻¹ + r²z⁻²)
    const double b0 = 1.0;
    final double  b1 = -2.0 * cosW0;
    const double  b2 = 1.0;
    final double  a1 = -2.0 * r * cosW0;
    final double  a2 = r * r;

    final y = List<double>.filled(x.length, 0.0);
    double x1 = x.isNotEmpty ? x[0] : 0.0;
    double x2 = x.isNotEmpty ? x[0] : 0.0;
    double y1 = 0.0, y2 = 0.0;
    for (int i = 0; i < x.length; i++) {
      final xi = x[i];
      final yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      y[i] = yi;
      x2 = x1; x1 = xi;
      y2 = y1; y1 = yi;
    }
    return y;
  }
}
