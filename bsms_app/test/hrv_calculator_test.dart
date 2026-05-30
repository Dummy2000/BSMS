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
      // 800 ok; 50 drop; 800 (vs lastValid 800) ok; 2500 drop
      expect(HrvCalculator.nnIntervals(peaks), [800, 800]);
    });

    test('drops RR differing > 20 % from previous valid RR (ectopic filter)', () {
      // RR = [800, 800, 1000]; 1000 vs 800 → 200 ms > 160 ms (20 %) → dropped
      final peaks = [0, 800, 1600, 2600];
      expect(HrvCalculator.nnIntervals(peaks), [800, 800]);
    });

    test('accepts RR within the 20 % difference band', () {
      // RR = [800, 920]; 920 vs 800 = 120 ms ≤ 160 ms → kept
      final peaks = [0, 800, 1720];
      expect(HrvCalculator.nnIntervals(peaks), [800, 920]);
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
