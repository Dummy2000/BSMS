import 'dart:math' as math;

/// Heart-rate-variability (HRV) calculation from R-peak timestamps.
///
/// Pure Dart, no external package. Provides:
///   • Static, stateless helpers for artefact filtering, RMSSD and SDNN
///     (used for per-session analysis and unit testing).
///   • A stateful moving-window mode for live RMSSD during a recording.
///
/// **Artefact filtering** (applied to both metrics): R-peak timestamps are
/// converted to RR intervals, then an interval is kept ("NN interval") only if
///   1. it lies within [[minRrMs], [maxRrMs]] (200…30 BPM), and
///   2. it differs by at most [maxRelDiff] (20 %) from the previous *valid* RR
///      (removes ectopic beats that would otherwise inflate RMSSD).
class HrvCalculator {
  // ── Filter configuration ────────────────────────────────────────────────
  static const int    minRrMs    = 300;   // 200 BPM
  static const int    maxRrMs    = 2000;  // 30 BPM
  static const double maxRelDiff = 0.20;  // 20 % change vs. previous valid RR

  // ── Live moving-window configuration ───────────────────────────────────────
  /// Length of the sliding window for live RMSSD.
  final int windowMs;

  /// Minimum spacing between RMSSD recomputations.
  final int updateIntervalMs;

  /// Minimum number of NN intervals required in the window to report RMSSD.
  final int minNnForRmssd;

  HrvCalculator({
    this.windowMs = 90000,        // 90 s
    this.updateIntervalMs = 10000, // 10 s
    this.minNnForRmssd = 16,
  });

  // ── Live state ────────────────────────────────────────────────────────────
  int? _lastPeakMs;
  int? _lastValidRr;
  final List<({int tMs, int rr})> _window = [];
  double? _rmssd;
  int? _lastUpdateMs;

  /// Most recent live RMSSD in ms, or null when the window does not yet hold
  /// enough NN intervals (e.g. window not full, or heart rate very low).
  double? get rmssd => _rmssd;

  /// Number of NN intervals currently inside the moving window.
  int get nnCountInWindow => _window.length;

  /// Clears all live state. Call when a new recording starts.
  void reset() {
    _lastPeakMs = null;
    _lastValidRr = null;
    _window.clear();
    _rmssd = null;
    _lastUpdateMs = null;
  }

  /// Feeds one R-peak timestamp (ms) into the live moving-window RMSSD.
  ///
  /// Timestamps must be monotonically increasing. RMSSD is recomputed at most
  /// once every [updateIntervalMs]; read the result via [rmssd].
  void addPeak(int peakMs) {
    if (_lastPeakMs != null) {
      final rr = peakMs - _lastPeakMs!;
      if (_acceptRr(rr, _lastValidRr)) {
        _window.add((tMs: peakMs, rr: rr));
        _lastValidRr = rr;
      }
    }
    _lastPeakMs = peakMs;

    // Drop NN intervals that fell out of the sliding window.
    final cutoff = peakMs - windowMs;
    _window.removeWhere((e) => e.tMs < cutoff);

    // Throttle recomputation to once per updateIntervalMs.
    _lastUpdateMs ??= peakMs;
    if (peakMs - _lastUpdateMs! >= updateIntervalMs) {
      _lastUpdateMs = peakMs;
      _rmssd = _window.length >= minNnForRmssd
          ? rmssdFromNn(_window.map((e) => e.rr).toList())
          : null;
    }
  }

  // ── Static helpers (session / tests) ────────────────────────────────────────

  /// True if [rr] passes the absolute and difference-based artefact filters.
  static bool _acceptRr(int rr, int? lastValidRr) {
    if (rr < minRrMs || rr > maxRrMs) return false;
    if (lastValidRr != null &&
        (rr - lastValidRr).abs() > maxRelDiff * lastValidRr) {
      return false;
    }
    return true;
  }

  /// Converts R-peak timestamps (ms) to filtered NN intervals (ms).
  static List<int> nnIntervals(List<int> peakTimestampsMs) {
    final nn = <int>[];
    int? lastValid;
    for (int i = 1; i < peakTimestampsMs.length; i++) {
      final rr = peakTimestampsMs[i] - peakTimestampsMs[i - 1];
      if (!_acceptRr(rr, lastValid)) continue;
      nn.add(rr);
      lastValid = rr;
    }
    return nn;
  }

  /// RMSSD (ms) over a list of NN intervals:
  /// `sqrt( mean( (NN[i+1] - NN[i])^2 ) )`. Null if fewer than 2 NN intervals.
  static double? rmssdFromNn(List<int> nn) {
    if (nn.length < 2) return null;
    double sumSq = 0;
    for (int i = 1; i < nn.length; i++) {
      final d = nn[i] - nn[i - 1];
      sumSq += d * d;
    }
    return math.sqrt(sumSq / (nn.length - 1));
  }

  /// RMSSD (ms) computed over all R-peak timestamps (full series, not windowed).
  /// Null if fewer than [minNn] valid NN intervals remain after filtering.
  static double? rmssdForSeries(List<int> peakTimestampsMs, {int minNn = 2}) {
    final nn = nnIntervals(peakTimestampsMs);
    if (nn.length < minNn) return null;
    return rmssdFromNn(nn);
  }

  /// SDNN (ms): standard deviation of all valid NN intervals over the whole
  /// recording. Uses the sample standard deviation (denominator N−1), matching
  /// common HRV tooling. Null if fewer than [minNn] valid NN intervals remain.
  static double? sdnn(List<int> peakTimestampsMs, {int minNn = 2}) {
    final nn = nnIntervals(peakTimestampsMs);
    if (nn.length < minNn) return null;
    final mean = nn.reduce((a, b) => a + b) / nn.length;
    double sumSq = 0;
    for (final v in nn) {
      final d = v - mean;
      sumSq += d * d;
    }
    return math.sqrt(sumSq / (nn.length - 1));
  }
}
