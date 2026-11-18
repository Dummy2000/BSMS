import 'dart:math' as math;

/// One kept RR interval: [tMs] = timestamp of the R-peak that ends it,
/// [adjPrev] = true if the RR interval right before it was kept as well
/// (only such pairs may be used for successive differences).
typedef _NnInterval = ({int tMs, int rr, bool adjPrev});

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
///   2. it differs by at most [maxRelDiff] (20 %) from the median of its
///      neighbouring plausible intervals: up to [refNeighbours] / 2 before and
///      after it for a whole series, the last [refNeighbours] for live RMSSD.
///      An interval with no neighbour to compare with is kept.
/// The reference is the median of the raw neighbours, not the last *kept*
/// interval, so one odd interval (missed beat, artefact) can't make the filter
/// reject everything after it, and a real change of rhythm is followed within
/// a few beats. RMSSD only uses differences between kept intervals that were
/// adjacent in the original series.
class HrvCalculator {
  // ── Filter configuration ────────────────────────────────────────────────
  static const int    minRrMs       = 300;  // 200 BPM
  static const int    maxRrMs       = 2000; // 30 BPM
  static const double maxRelDiff    = 0.20; // 20 % change vs. neighbour median
  static const int    refNeighbours = 6;    // size of the reference (see above)

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
  final List<int> _recentRr = []; // last [refNeighbours] plausible RRs, kept or not
  bool _lastRrKept = false;       // was the previous RR interval kept?
  final List<_NnInterval> _window = [];
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
    _recentRr.clear();
    _lastRrKept = false;
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
      final plausible = _inRange(rr);
      final keep = plausible && _withinReference(rr, _recentRr);
      if (keep) _window.add((tMs: peakMs, rr: rr, adjPrev: _lastRrKept));
      _lastRrKept = keep;
      if (plausible) {
        _recentRr.add(rr);
        if (_recentRr.length > refNeighbours) _recentRr.removeAt(0);
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
      _rmssd = _window.length >= minNnForRmssd ? _rmssdAdjacent(_window) : null;
    }
  }

  // ── Static helpers (session / tests) ────────────────────────────────────────

  /// Converts R-peak timestamps (ms) to filtered NN intervals (ms).
  static List<int> nnIntervals(List<int> peakTimestampsMs) =>
      _filterSeries(peakTimestampsMs).map((e) => e.rr).toList();

  /// RMSSD (ms) over a list of *consecutive* NN intervals:
  /// `sqrt( mean( (NN[i+1] - NN[i])^2 ) )`. Null if fewer than 2 NN intervals.
  ///
  /// For a filtered series (where intervals were removed in between) use
  /// [rmssdForSeries], which only pairs originally adjacent intervals.
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
  /// Null if fewer than [minNn] valid NN intervals remain after filtering, or if
  /// no two kept intervals were adjacent.
  static double? rmssdForSeries(List<int> peakTimestampsMs, {int minNn = 2}) {
    final nn = _filterSeries(peakTimestampsMs);
    if (nn.length < minNn) return null;
    return _rmssdAdjacent(nn);
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

  // ── Internals ──────────────────────────────────────────────────────────────

  static bool _inRange(int rr) => rr >= minRrMs && rr <= maxRrMs;

  /// True if [rr] is within [maxRelDiff] of the median of [reference]
  /// (or if there is nothing to compare with).
  static bool _withinReference(int rr, List<int> reference) {
    if (reference.isEmpty) return true;
    final ref = _median(reference);
    return (rr - ref).abs() <= maxRelDiff * ref;
  }

  static double _median(List<int> values) {
    final s = [...values]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2.0;
  }

  /// Artefact filter for a whole series: each plausible interval is compared
  /// with the median of up to [refNeighbours] / 2 plausible intervals on each
  /// side of it.
  static List<_NnInterval> _filterSeries(List<int> peakTimestampsMs) {
    // Plausible RR intervals and their position in the raw RR series.
    final pos = <int>[];
    final rr  = <int>[];
    for (int i = 1; i < peakTimestampsMs.length; i++) {
      final v = peakTimestampsMs[i] - peakTimestampsMs[i - 1];
      if (_inRange(v)) {
        pos.add(i - 1);
        rr.add(v);
      }
    }

    const side = refNeighbours ~/ 2;
    final out = <_NnInterval>[];
    int lastKeptPos = -2;
    for (int j = 0; j < rr.length; j++) {
      final reference = <int>[
        for (int q = math.max(0, j - side); q < j; q++) rr[q],
        for (int q = j + 1; q <= math.min(rr.length - 1, j + side); q++) rr[q],
      ];
      if (!_withinReference(rr[j], reference)) continue;
      out.add((
        tMs: peakTimestampsMs[pos[j] + 1],
        rr: rr[j],
        adjPrev: pos[j] == lastKeptPos + 1,
      ));
      lastKeptPos = pos[j];
    }
    return out;
  }

  /// RMSSD over kept intervals, using only pairs that were adjacent in the
  /// original series. Null if there is no such pair.
  static double? _rmssdAdjacent(List<_NnInterval> nn) {
    double sumSq = 0;
    int pairs = 0;
    for (int i = 1; i < nn.length; i++) {
      if (!nn[i].adjPrev) continue;
      final d = nn[i].rr - nn[i - 1].rr;
      sumSq += d * d;
      pairs++;
    }
    return pairs == 0 ? null : math.sqrt(sumSq / pairs);
  }
}
