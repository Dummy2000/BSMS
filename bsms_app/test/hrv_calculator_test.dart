import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:bsms_app/domain/processing/hrv_calculator.dart';

void main() {
  group('nnIntervals — artefact filtering', () {
    test('keeps physiologically plausible RR intervals', () {
      // RR = [800, 800, 800]
      final peaks = [0, 800, 1600, 2400];
      expect(HrvCalculator.nnIntervals(peaks), [800, 800, 800]);
    });

    test('drops RR below 300 ms and above 2000 ms (absolute filter)', () {
      // RR = [800, 50 (drop), 800, 2500 (drop)]
      // peaks: 0, 800, 850, 1650, 4150
      final peaks = [0, 800, 850, 1650, 4150];
      // 800 ok; 50 drop; 800 (neighbour median 800) ok; 2500 drop
      expect(HrvCalculator.nnIntervals(peaks), [800, 800]);
    });

    test('drops RR differing > 20 % from its neighbours (ectopic filter)', () {
      // RR = [800, 800, 1000]; neighbour median of 1000 is 800
      // → 200 ms > 160 ms (20 %) → dropped
      final peaks = [0, 800, 1600, 2600];
      expect(HrvCalculator.nnIntervals(peaks), [800, 800]);
    });

    test('accepts RR within the 20 % difference band', () {
      // RR = [800, 920]; 920 vs 800 = 120 ms ≤ 160 ms → kept
      final peaks = [0, 800, 1720];
      expect(HrvCalculator.nnIntervals(peaks), [800, 920]);
    });
  });

  group('artefact filter: no lock-out after one unusual interval', () {
    // R-peaks: 1 x 1500 ms (missed beat), then 101 x 800 ms. Comparing with the
    // last *kept* interval rejected everything after the 1500 → no HRV at all.
    final lockOutPeaks = [
      0, 1500,
      for (int t = 2300; t <= 2300 + 800 * 100; t += 800) t,
    ];

    List<int> peaksFromRr(List<int> rr) {
      final peaks = <int>[0];
      for (final v in rr) {
        peaks.add(peaks.last + v);
      }
      return peaks;
    }

    test('series: the intervals after an unusual first one are kept', () {
      final nn = HrvCalculator.nnIntervals(lockOutPeaks);
      expect(nn.length, 101);
      expect(nn, everyElement(800));
      expect(HrvCalculator.sdnn(lockOutPeaks), 0.0);
      expect(HrvCalculator.rmssdForSeries(lockOutPeaks), 0.0);
    });

    test('live: RMSSD is available after an unusual first interval', () {
      final hrv = HrvCalculator(minNnForRmssd: 16);
      for (final t in lockOutPeaks) {
        hrv.addPeak(t);
      }
      expect(hrv.rmssd, isNotNull);
      expect(hrv.rmssd!, closeTo(0.0, 1e-9));
    });

    test('a lasting change of rhythm > 20 % is followed', () {
      // 30 x 1000 ms, then 30 x 700 ms (e.g. HR rose during a lead-off gap).
      // Before the fix all 700 ms intervals were rejected.
      final peaks = peaksFromRr([...List.filled(30, 1000), ...List.filled(30, 700)]);
      expect(HrvCalculator.nnIntervals(peaks).where((v) => v == 700).length, 30);

      final hrv = HrvCalculator(minNnForRmssd: 2, updateIntervalMs: 0);
      for (final t in peaks) {
        hrv.addPeak(t);
      }
      // Live only looks back, so the first 3 intervals after the jump are
      // rejected: 30 + 27 kept.
      expect(hrv.nnCountInWindow, 57);
    });

    test('RMSSD only pairs intervals that were adjacent before filtering', () {
      // 800, 810, 800, then an ectopic beat (500 + 1100, both dropped), then
      // 900, 910, 900. Adjacent pairs all differ by 10 ms → RMSSD 10.
      // Pairing 800 → 900 across the dropped beats would give ~45.6.
      final peaks = peaksFromRr([800, 810, 800, 500, 1100, 900, 910, 900]);
      expect(HrvCalculator.nnIntervals(peaks), [800, 810, 800, 900, 910, 900]);
      expect(HrvCalculator.rmssdForSeries(peaks), closeTo(10.0, 1e-9));

      final hrv = HrvCalculator(minNnForRmssd: 2, updateIntervalMs: 0);
      for (final t in peaks) {
        hrv.addPeak(t);
      }
      expect(hrv.rmssd!, closeTo(10.0, 1e-9));
    });
  });

  group('RMSSD', () {
    test('is zero for perfectly constant NN intervals', () {
      final peaks = [0, 800, 1600, 2400, 3200];
      expect(HrvCalculator.rmssdForSeries(peaks), 0.0);
    });

    test('matches hand-computed value', () {
      // NN = [800, 840, 800]; diffs = [40, -40]; squares = [1600, 1600];
      // mean over (N-1)=2 → 1600; sqrt → 40
      final peaks = [0, 800, 1640, 2440];
      expect(HrvCalculator.nnIntervals(peaks), [800, 840, 800]);
      expect(HrvCalculator.rmssdForSeries(peaks), closeTo(40.0, 1e-9));
    });

    test('returns null when fewer than 2 NN intervals', () {
      expect(HrvCalculator.rmssdForSeries([0, 800]), isNull); // 1 NN interval
      expect(HrvCalculator.rmssdForSeries([0]), isNull);
      expect(HrvCalculator.rmssdForSeries(const []), isNull);
    });
  });

  group('SDNN', () {
    test('is zero for constant NN intervals', () {
      final peaks = [0, 800, 1600, 2400, 3200];
      expect(HrvCalculator.sdnn(peaks), 0.0);
    });

    test('matches hand-computed sample standard deviation', () {
      // NN = [800, 820, 800, 820, 800]; mean = 808
      // squared deviations: 64,144,64,144,64 = 480
      // sample variance = 480 / (5-1) = 120 → sdnn = sqrt(120) ≈ 10.954
      final peaks = [0, 800, 1620, 2420, 3240, 4040];
      expect(HrvCalculator.nnIntervals(peaks), [800, 820, 800, 820, 800]);
      expect(HrvCalculator.sdnn(peaks), closeTo(math.sqrt(120), 1e-9));
    });

    test('returns null below the minimum NN count', () {
      expect(HrvCalculator.sdnn([0, 800], minNn: 5), isNull);
      expect(HrvCalculator.sdnn(const [], minNn: 2), isNull);
    });
  });

  group('Live moving-window RMSSD', () {
    test('is null before enough NN intervals accumulate', () {
      final hrv = HrvCalculator(
          windowMs: 90000, updateIntervalMs: 10000, minNnForRmssd: 16);
      // Feed only 5 beats → 4 NN, far below 16.
      for (int t = 0; t <= 4000; t += 1000) {
        hrv.addPeak(t);
      }
      expect(hrv.rmssd, isNull);
    });

    test('reports ~0 RMSSD for a steady rhythm once the window has data', () {
      final hrv = HrvCalculator(
          windowMs: 90000, updateIntervalMs: 10000, minNnForRmssd: 5);
      // Steady 1000 ms RR from 0 to 20 s → 20 NN intervals of 1000 ms.
      for (int t = 0; t <= 20000; t += 1000) {
        hrv.addPeak(t);
      }
      // A recompute is triggered at t ≥ 10000; window holds enough NN.
      expect(hrv.rmssd, isNotNull);
      expect(hrv.rmssd!, closeTo(0.0, 1e-9));
    });

    test('prunes NN intervals older than the window', () {
      final hrv = HrvCalculator(
          windowMs: 5000, updateIntervalMs: 1000, minNnForRmssd: 2);
      for (int t = 0; t <= 60000; t += 1000) {
        hrv.addPeak(t);
      }
      // 5 s window at 1 s RR → ~5-6 NN intervals retained (far below the 60 fed).
      expect(hrv.nnCountInWindow, lessThanOrEqualTo(6));
    });

    test('reset clears state', () {
      final hrv = HrvCalculator(minNnForRmssd: 2, updateIntervalMs: 1000);
      for (int t = 0; t <= 10000; t += 1000) {
        hrv.addPeak(t);
      }
      hrv.reset();
      expect(hrv.rmssd, isNull);
      expect(hrv.nnCountInWindow, 0);
    });
  });
}
