import 'dart:math' as math;
import '../ecg_sample.dart';

/// R-peak detector based on the Pan-Tompkins algorithm.
///
/// Pipeline: differentiate → square → moving-window integrate → adaptive threshold.
/// Input should be bandpass-filtered (0.5–40 Hz) ECG samples at 500 Hz.
class RPeakDetector {
  static const int _sampleRateHz = 500;

  /// Returns the sample indices of detected R-peaks within [filteredSamples].
  static List<int> detect(List<EcgSample> filteredSamples) {
    if (filteredSamples.length < 10) return [];

    final x = filteredSamples.map((s) => s.value.toDouble()).toList();

    final diff = _differentiate(x);
    final squared = List<double>.generate(diff.length, (i) => diff[i] * diff[i]);
    // 150 ms integration window
    final integrated = _movingAverage(squared, (_sampleRateHz * 0.150).round());

    return _adaptiveThreshold(integrated, minGapSamples: (_sampleRateHz * 0.30).round());
  }

  /// 5-point derivative (Pan-Tompkins).
  static List<double> _differentiate(List<double> x) {
    final y = List<double>.filled(x.length, 0.0);
    for (int i = 2; i < x.length - 2; i++) {
      y[i] = (-x[i - 2] - 2 * x[i - 1] + 2 * x[i + 1] + x[i + 2]) / 8.0;
    }
    return y;
  }

  static List<double> _movingAverage(List<double> x, int window) {
    final y = List<double>.filled(x.length, 0.0);
    double sum = 0;
    for (int i = 0; i < x.length; i++) {
      sum += x[i];
      if (i >= window) sum -= x[i - window];
      y[i] = sum / math.min(i + 1, window);
    }
    return y;
  }

  /// Adaptive threshold peak finder.
  ///
  /// Maintains a running estimate of signal peak amplitude and sets the
  /// detection threshold at 50 % of that estimate, updated after every beat.
  static List<int> _adaptiveThreshold(List<double> signal, {required int minGapSamples}) {
    final peaks = <int>[];
    if (signal.isEmpty) return peaks;

    // Seed threshold from first 2 seconds of signal.
    final seedEnd = math.min(_sampleRateHz * 2, signal.length);
    double spki = signal.sublist(0, seedEnd).reduce(math.max);
    double threshold = spki * 0.5;
    int lastPeak = -minGapSamples;

    for (int i = 1; i < signal.length - 1; i++) {
      final isLocalMax = signal[i] >= signal[i - 1] && signal[i] > signal[i + 1];
      if (isLocalMax && signal[i] > threshold && i - lastPeak >= minGapSamples) {
        peaks.add(i);
        lastPeak = i;
        // Exponential moving average update.
        spki = 0.875 * spki + 0.125 * signal[i];
        threshold = 0.5 * spki;
      }
    }
    return peaks;
  }
}
