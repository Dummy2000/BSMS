import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:bsms_app/data/ble/ble_recording_service.dart';

/// Synthetic ECG at 500 Hz in raw ADC units, as the app receives it from the
/// ESP32: [baseline] (13200 LSB) plus uniform noise of ±10 LSB. Each beat is a
/// Gaussian R wave (+1000 LSB unless [rAmp] says otherwise, σ = 10 samples)
/// and a T wave (+250 LSB, σ = 20 samples) 125 samples later.
/// [steps] adds rectangular artefacts: (start sample, length, amplitude).
List<int> _ecg(
  List<int> rPeaks,
  int length, {
  int seed = 1,
  int baseline = 13200,
  Map<int, double> rAmp = const {},
  List<(int, int, int)> steps = const [],
}) {
  final rnd = math.Random(seed);
  final x = List<double>.generate(
      length, (_) => baseline + (rnd.nextDouble() - 0.5) * 20);
  void bump(int centre, double amp, double sigma) {
    final w = (sigma * 5).round();
    for (int i = math.max(0, centre - w); i < math.min(length, centre + w); i++) {
      final d = (i - centre) / sigma;
      x[i] += amp * math.exp(-0.5 * d * d);
    }
  }

  for (int b = 0; b < rPeaks.length; b++) {
    bump(rPeaks[b], rAmp[b] ?? 1000, 10);
    bump(rPeaks[b] + 125, 250, 20);
  }
  for (final (start, len, amp) in steps) {
    for (int i = start; i < math.min(length, start + len); i++) {
      x[i] += amp;
    }
  }
  return x.map((v) => v.round()).toList();
}

/// Feeds [signal] sample by sample into the live detector and returns the
/// stored R-peak indices.
List<int> _detect(List<int> signal) {
  final pipeline = StreamingPipeline();
  final peaks = <int>[];
  for (int i = 0; i < signal.length; i++) {
    peaks.addAll(pipeline.processSample(signal[i], i));
  }
  return peaks;
}

/// Matches each true beat to at most one stored peak in [beat - 60, beat + 150]
/// (the detector marks the maximum of the moving-window integral, which comes
/// ~40 samples after the R apex).
({List<int> missed, List<int> extra}) _match(List<int> beats, List<int> peaks) {
  final used = List<bool>.filled(peaks.length, false);
  final missed = <int>[];
  for (final b in beats) {
    final j = Iterable<int>.generate(peaks.length).firstWhere(
        (j) => !used[j] && peaks[j] >= b - 60 && peaks[j] <= b + 150,
        orElse: () => -1);
    if (j < 0) {
      missed.add(b);
    } else {
      used[j] = true;
    }
  }
  return (
    missed: missed,
    extra: [for (int j = 0; j < peaks.length; j++) if (!used[j]) peaks[j]],
  );
}

void main() {
  group('StreamingPipeline (live R-peak detection)', () {
    test('raw ADC input: beats are found from the start, no start-up peaks', () {
      // 2 min at 75 bpm, first beat at 2 s. Before the fix the filters started
      // from 0, the baseline step dominated threshold learning, and the first
      // real beat was only found after ~55 s.
      final beats = [for (int t = 1000; t < 60000; t += 400) t];
      final m = _match(beats, _detect(_ecg(beats, 60000, seed: 3)));
      expect(m.extra, isEmpty, reason: 'fake peaks');
      expect(m.missed, isEmpty, reason: 'missed beats');
    });

    test('a 3 s pause does not produce duplicate R-peaks', () {
      // Without baseline, so only the searchback is tested (not the start-up
      // fix above). Before the fix the searchback stored 9892, 9893 and 9894
      // inside the pause, and the first beat twice (986 and 1086).
      final beats = [for (int t = 1000; t < 10000; t += 400) t];
      beats.addAll([for (int t = beats.last + 1500; t < 16000; t += 400) t]);
      final peaks = _detect(_ecg(beats, 16000, baseline: 0));
      final m = _match(beats, peaks);
      expect(m.extra, isEmpty, reason: 'fake/duplicate peaks');
      expect(m.missed, isEmpty, reason: 'missed beats');
      for (int i = 1; i < peaks.length; i++) {
        expect(peaks[i] - peaks[i - 1], greaterThanOrEqualTo(100),
            reason: 'peaks closer than 200 ms: ${peaks[i - 1]}, ${peaks[i]}');
      }
    });

    test('searchback still recovers a low beat at its own position', () {
      // Beat 10 has less than half the normal amplitude: normal tracking
      // misses it, searchback has to find it (within the match window).
      final beats = [for (int t = 1000; t < 30000; t += 400) t];
      final m = _match(beats, _detect(_ecg(beats, 30000, rAmp: {10: 450})));
      expect(m.missed, isEmpty, reason: 'missed beats');
      expect(m.extra, isEmpty, reason: 'fake peaks');
    });

    test('recovers within seconds from an artefact in the first 2 s', () {
      // +8000 LSB for 300 ms at t = 1 s inflates the learned thresholds. The
      // detector re-learns 3 s after the learning phase if it found nothing.
      final beats = [for (int t = 300; t < 30000; t += 400) t];
      final peaks = _detect(
          _ecg(beats, 30000, seed: 2, steps: [(500, 150, 8000)]));
      final m = _match(beats, peaks);
      expect(m.extra, isEmpty, reason: 'fake peaks');
      expect(m.missed.where((b) => b > 3000), isEmpty,
          reason: 'beats missed after the first 6 s');
    });
  });
}
