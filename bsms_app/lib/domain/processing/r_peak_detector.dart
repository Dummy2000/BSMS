import 'dart:math' as math;
import '../ecg_sample.dart';

/// R-peak detector based on the Pan-Tompkins algorithm.
/// Pan & Tompkins (1985) IEEE TBME 32(3):230-236.
///
/// Pipeline: 5-point derivative → square → 150 ms MWI → adaptive threshold.
/// Input must be bandpass-filtered (0.5–40 Hz) ECG at 500 Hz.
///
/// Improvements over the naive version:
///   • Dual threshold: SPKI (signal) + NPKI (noise), as per original paper.
///   • T-wave discrimination: peaks within 360 ms of last beat and < 50 %
///     amplitude are classified as T-waves, not R-peaks.
///   • Searchback: gaps > 1.66 × mean RR are searched with a 50 % threshold.
///   • Refractory period: 200 ms (100 samples), matching the paper.
class RPeakDetector {
  static const int _fs           = 500;
  static const int _refractory   = 100;  // samples = 200 ms
  static const int _tWaveWindow  = 180;  // samples = 360 ms
  static const int _initSamples  = 1000; // 2 s seed window

  static List<int> detect(List<EcgSample> filteredSamples) {
    if (filteredSamples.length < _initSamples) return [];

    final x   = filteredSamples.map((s) => s.value.toDouble()).toList();
    final dif = _differentiate(x);
    final sq  = List<double>.generate(dif.length, (i) => dif[i] * dif[i]);
    // 150 ms moving-window integration (75 samples at 500 Hz)
    final mwi = _movingAverage(sq, (_fs * 0.150).round());

    return _panTompkins(mwi);
  }

  // ── 5-point Pan-Tompkins derivative (offline, non-causal) ──────────────────
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

  // ── Full Pan-Tompkins detection pass ───────────────────────────────────────
  static List<int> _panTompkins(List<double> mwi) {
    // Seed thresholds from the first 2 s.
    // SPKI = 50 % of seed max (conservative — avoids motion-artifact inflation).
    // NPKI = 5 % of seed max (initial noise floor).
    final seedMax = mwi.sublist(0, _initSamples).reduce(math.max);
    double spki = seedMax * 0.5;
    double npki = seedMax * 0.05;
    double thr1 = npki + 0.25 * (spki - npki); // primary threshold

    final peaks  = <int>[];
    int    lastPeak    = -_refractory;
    double lastPeakMwi = 0.0;
    double meanRr      = 0.0;

    for (int i = 1; i < mwi.length - 1; i++) {
      // Active threshold decay: if no beat for > 1.5 × meanRR, decay SPKI at
      // 5.75 %/s (PLOS ONE 2016) so a noise-inflated threshold recovers.
      // Floored at NPKI so the threshold never inverts.
      if (meanRr > 0 && (i - lastPeak) > meanRr * 1.5 && spki > npki) {
        spki = math.max(npki, spki * 0.99988); // ≈ 5.75 %/s at 500 Hz
        thr1 = npki + 0.25 * (spki - npki);
      }

      final v = mwi[i];

      // Strict local maximum (last sample of any equal-valued plateau).
      if (v < mwi[i - 1] || v <= mwi[i + 1]) continue;

      if (v <= thr1) {
        // Sub-threshold → noise update.
        npki = 0.125 * v + 0.875 * npki;
        thr1 = npki + 0.25 * (spki - npki);
        continue;
      }

      if (i - lastPeak < _refractory) continue;

      // T-wave discrimination.
      if (lastPeak >= 0 && i - lastPeak < _tWaveWindow &&
          v < 0.5 * lastPeakMwi) {
        npki = 0.125 * v + 0.875 * npki;
        thr1 = npki + 0.25 * (spki - npki);
        continue;
      }

      // Confirmed R-peak. Cap SPKI increase to ×1.5 (Biomed Eng Online).
      peaks.add(i);
      spki = math.min(0.125 * v + 0.875 * spki, spki * 1.5);
      if (lastPeak >= 0) {
        final rr = i - lastPeak;
        meanRr = meanRr == 0 ? rr.toDouble() : 0.125 * rr + 0.875 * meanRr;
      }
      lastPeakMwi = v;
      lastPeak    = i;
      thr1 = npki + 0.25 * (spki - npki);
    }

    // ── Searchback: fill gaps > 1.66 × meanRR with half-threshold ────────────
    if (meanRr > 0) {
      final extras = _searchback(mwi, peaks, meanRr, thr1 * 0.5);
      if (extras.isNotEmpty) {
        peaks.addAll(extras);
        peaks.sort();
        _deduplicate(peaks); // remove any pair closer than _refractory
      }
    }

    return peaks;
  }

  // ── Offline searchback ─────────────────────────────────────────────────────
  static List<int> _searchback(
    List<double> mwi,
    List<int> peaks,
    double meanRr,
    double halfThr,
  ) {
    final extra    = <int>[];
    final gapLimit = (meanRr * 1.66).round();

    // Gap before first detected peak.
    if (peaks.isNotEmpty && peaks.first > gapLimit) {
      // Upper bound is peaks.first - _refractory so the inserted peak stays
      // at least _refractory samples away from the first already-detected peak.
      _bestInRange(mwi, _refractory, peaks.first - _refractory, halfThr, extra);
    }

    for (int i = 1; i < peaks.length; i++) {
      if (peaks[i] - peaks[i - 1] > gapLimit) {
        // Keep at least _refractory samples away from BOTH surrounding peaks.
        _bestInRange(
            mwi,
            peaks[i - 1] + _refractory,
            peaks[i]     - _refractory,
            halfThr,
            extra);
      }
    }
    return extra;
  }

  static void _bestInRange(
    List<double> mwi,
    int from,
    int to,
    double minVal,
    List<int> out,
  ) {
    from = math.max(from, 0);
    to   = math.min(to, mwi.length);
    if (from >= to) return;
    double best = minVal;
    int    idx  = -1;
    for (int j = from; j < to; j++) {
      if (mwi[j] > best) { best = mwi[j]; idx = j; }
    }
    if (idx >= 0) out.add(idx);
  }

  // ── Remove any peaks closer than _refractory to the previous one ───────────
  static void _deduplicate(List<int> peaks) {
    int i = 1;
    while (i < peaks.length) {
      if (peaks[i] - peaks[i - 1] < _refractory) {
        peaks.removeAt(i);
      } else {
        i++;
      }
    }
  }
}
