import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../domain/models/imported_session.dart';
import '../../domain/models/person.dart';
import '../storage/session_storage_service.dart';
import '../../domain/processing/hrv_calculator.dart';
import 'ecg_ble_service.dart';
import 'ecg_packet.dart';
import 'ecg_packet_parser.dart';

class RecordingStatus {
  final Duration elapsed;
  final int sampleCount;
  final int currentHr;
  final bool connected;

  /// Live RMSSD (ms) over a 90 s moving window, or null when not yet available
  /// (window not full / heart rate too low). Updated ~every 10 s.
  final double? rmssd;

  const RecordingStatus({
    required this.elapsed,
    required this.sampleCount,
    required this.currentHr,
    required this.connected,
    this.rmssd,
  });
}

/// Records BLE ECG data directly to disk without buffering samples in RAM.
///
/// Each incoming [EcgPacket] is immediately serialised to the 51-byte SD-card
/// format and written to a [RandomAccessFile], so a 12-hour session (~55 MB)
/// never accumulates in memory.  R-peak detection runs sample-by-sample via a
/// stateful streaming pipeline — only the resulting indices (~200 KB) are kept.
class BleRecordingService {
  final EcgBleService _bleService;
  final SessionStorageService _storageService;

  // ── Recording state ───────────────────────────────────────────────────────
  Person? _person;
  String? _sessionId;
  DateTime? _startTime;

  RandomAccessFile? _rawFile;  // 51-byte ECG packets
  RandomAccessFile? _hrFile;   // 9-byte HR entries (int64 ts + uint8 bpm)

  int _packetCount      = 0;
  int _globalSampleIdx  = 0;
  int _firstSampleTsMs  = 0;
  bool _bleConnected    = false;
  int  _disconnectStartSampleIdx = 0;

  bool _inLeadOff    = false;
  int  _leadOffStart = 0;

  final List<int>               _rPeakIndices       = [];
  final List<LeadOffInterval>   _leadOffIntervals   = [];
  final List<DisconnectInterval> _disconnectIntervals = [];

  final _pipeline = _StreamingPipeline();
  final _hrv = HrvCalculator(); // live 90 s RMSSD, recomputed every 10 s

  StreamSubscription<EcgPacket>? _packetSub;
  StreamSubscription<bool>?      _connSub;

  final _statusCtrl = StreamController<RecordingStatus>.broadcast();

  // ── Public API ────────────────────────────────────────────────────────────

  Stream<RecordingStatus> get status => _statusCtrl.stream;
  bool    get isRecording    => _rawFile != null;
  Person? get currentPerson  => _person;

  BleRecordingService(this._bleService, this._storageService);

  Future<void> startRecording(Person person) async {
    if (isRecording) return;

    _person       = person;
    _sessionId    = DateTime.now().microsecondsSinceEpoch.toString();
    _startTime    = DateTime.now();
    _packetCount  = 0;
    _globalSampleIdx = 0;
    _firstSampleTsMs = 0;
    _bleConnected = _bleService.isConnected;
    _rPeakIndices.clear();
    _leadOffIntervals.clear();
    _disconnectIntervals.clear();
    _pipeline.reset();
    _hrv.reset();

    final dir = await _sessionsDirectory();
    _rawFile = await File('$dir/$_sessionId.bin').open(mode: FileMode.write);
    _hrFile  = await File('$dir/${_sessionId}_hr.bin').open(mode: FileMode.write);

    try { await WakelockPlus.enable(); } catch (_) {}

    _connSub = _bleService.connectionState.listen(_onConnectionChange);
    _packetSub = _bleService.ecgPackets.listen(_onPacket, onError: (_) {});
  }

  Future<ImportedSession> stopRecording() async {
    if (!isRecording) throw StateError('Not recording');

    await _packetSub?.cancel();
    await _connSub?.cancel();
    _packetSub = null;
    _connSub   = null;

    if (_inLeadOff) {
      _leadOffIntervals.add(LeadOffInterval(
          startMs: _leadOffStart, endMs: _globalSampleIdx * 2));
    }

    await _rawFile!.flush();
    await _rawFile!.close();
    await _hrFile!.flush();
    await _hrFile!.close();
    _rawFile = null;
    _hrFile  = null;

    try { await WakelockPlus.disable(); } catch (_) {}

    final dir          = await _sessionsDirectory();
    final rPeaksPath   = '$dir/${_sessionId}_rpeaks.bin';
    final hrFilePath   = '$dir/${_sessionId}_hr.bin';
    final rawFilePath  = '$dir/$_sessionId.bin';

    // Write R-peak indices
    if (_rPeakIndices.isNotEmpty) {
      final bd = ByteData(_rPeakIndices.length * 4);
      for (int i = 0; i < _rPeakIndices.length; i++) {
        bd.setInt32(i * 4, _rPeakIndices[i], Endian.little);
      }
      await File(rPeaksPath).writeAsBytes(bd.buffer.asUint8List());
    }

    final session = ImportedSession(
      id:                    _sessionId!,
      sourceFile:            'BLE – ${_person!.name}',
      importedAt:            _startTime!,
      skippedPackets:        0,
      personId:              _person!.id,
      filePath:              rawFilePath,
      firstSampleTimestampMs: _firstSampleTsMs,
      totalSampleCount:      _globalSampleIdx,
      totalDurationMs:       _globalSampleIdx * 2,
      rPeakIndices:          List.unmodifiable(_rPeakIndices),
      leadOffIntervals:      List.unmodifiable(_leadOffIntervals),
      disconnectIntervals:   List.unmodifiable(_disconnectIntervals),
    );

    await _storageService.saveSession(
      session,
      hrFilePath:    hrFilePath,
      rPeaksFilePath: _rPeakIndices.isNotEmpty ? rPeaksPath : null,
    );

    _person    = null;
    _sessionId = null;
    return session;
  }

  void dispose() {
    _packetSub?.cancel();
    _connSub?.cancel();
    _statusCtrl.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onConnectionChange(bool connected) {
    if (!isRecording) return;
    if (!connected && _bleConnected) {
      _bleConnected = false;
      _disconnectStartSampleIdx = _globalSampleIdx;
    } else if (connected && !_bleConnected) {
      _bleConnected = true;
      if (_disconnectStartSampleIdx > 0) {
        _disconnectIntervals.add(DisconnectInterval(
          startMs: _disconnectStartSampleIdx * 2,
          endMs:   _globalSampleIdx * 2,
        ));
        _disconnectStartSampleIdx = 0;
      }
    }
  }

  void _onPacket(EcgPacket packet) {
    if (!isRecording) return;

    final pTsMs = packet.timestamp.millisecondsSinceEpoch;

    // Capture first timestamp for relative-to-absolute conversion in reader.
    if (_firstSampleTsMs == 0) _firstSampleTsMs = pTsMs;

    // Write raw 51-byte block immediately — no sample buffering.
    try {
      _rawFile!.writeFromSync(_serializePacket(packet));
    } catch (e) {
      _statusCtrl.addError('Schreibfehler (Speicher voll?): $e');
      return; // drop this packet but keep recording so UI can show the error
    }
    _packetCount++;

    // Periodic flush every 5 seconds (125 packets at 25 packets/s).
    if (_packetCount % 125 == 0) {
      _rawFile!.flushSync();
      _hrFile!.flushSync();
    }

    // Write HR entry if firmware has a valid value.
    if (packet.heartRate > 0) {
      final bd = ByteData(9);
      bd.setInt64(0, pTsMs, Endian.little);
      bd.setUint8(8, packet.heartRate);
      try {
        _hrFile!.writeFromSync(bd.buffer.asUint8List());
      } catch (_) {} // HR is supplementary; ECG data loss is already reported above
    }

    // Streaming R-peak detection — may return 0, 1 or 2 peaks per sample
    // (searchback can retroactively yield a missed peak alongside a new one).
    for (int i = 0; i < packet.samples.length; i++) {
      final gIdx = _globalSampleIdx + i;
      final peaks = _pipeline.processSample(packet.samples[i], gIdx);
      for (final p in peaks) {
        _rPeakIndices.add(p);
        _hrv.addPeak(p * 2); // 2 ms/sample → recording-relative timestamp
      }
    }
    _globalSampleIdx += packet.samples.length;

    // Lead-off tracking from status flags.
    final isLeadOff = (packet.flags & 0x03) != 0;
    if (isLeadOff && !_inLeadOff) {
      _inLeadOff    = true;
      _leadOffStart = pTsMs - _firstSampleTsMs;
    } else if (!isLeadOff && _inLeadOff) {
      _inLeadOff = false;
      _leadOffIntervals.add(LeadOffInterval(
          startMs: _leadOffStart,
          endMs:   pTsMs - _firstSampleTsMs));
    }

    // Status update approximately once per second.
    if (_packetCount % 25 == 0) {
      _statusCtrl.add(RecordingStatus(
        elapsed:    DateTime.now().difference(_startTime!),
        sampleCount: _globalSampleIdx,
        currentHr:   _pipeline.currentHr,
        connected:   _bleConnected,
        rmssd:       _hrv.rmssd,
      ));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<String> _sessionsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/sessions');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static Uint8List _serializePacket(EcgPacket packet) {
    final bd = ByteData(EcgPacketParser.packetSize); // 51
    bd.setInt64(0, packet.timestamp.millisecondsSinceEpoch, Endian.little);
    bd.setUint8(8, packet.heartRate);
    bd.setUint8(9, EcgPacketParser.samplesPerPacket);
    bd.setUint8(10, packet.flags);
    for (int i = 0; i < EcgPacketParser.samplesPerPacket; i++) {
      bd.setUint16(11 + i * 2, packet.samples[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }
}

// ── Streaming Pan-Tompkins pipeline ──────────────────────────────────────────
//
// Implements the full Pan & Tompkins (1985) algorithm with:
//   • Dual threshold: SPKI (signal peaks) + NPKI (noise peaks)
//   • T-wave discrimination: peaks within 360 ms at < 50 % amplitude → T-wave
//   • Searchback: if no beat for > 1.66 × meanRR, re-scan buffer at 50 % threshold
//   • Better initialisation: SPKI = 50 % of init max, NPKI = 5 % of init max

class _StreamingPipeline {
  static const double _fs = 500.0;

  // IIR filter coefficients (computed once in _computeCoefficients).
  late double _hpB0, _hpB1, _hpB2, _hpA1, _hpA2;
  late double _lpB0, _lpB1, _lpB2, _lpA1, _lpA2;
  late double _ntB1, _ntA1, _ntA2; // notch: b0=b2=1

  // Filter state
  double _hpX1 = 0, _hpX2 = 0, _hpY1 = 0, _hpY2 = 0;
  double _lpX1 = 0, _lpX2 = 0, _lpY1 = 0, _lpY2 = 0;
  double _ntX1 = 0, _ntX2 = 0, _ntY1 = 0, _ntY2 = 0;

  // Pan-Tompkins differentiation + MWI
  final _diffBuf = List<double>.filled(5, 0.0);
  final _mwiBuf  = List<double>.filled(75, 0.0); // 150 ms at 500 Hz
  int    _mwiIdx = 0;
  double _mwiSum = 0.0;

  // Threshold initialisation (first 2 s = 1000 samples)
  bool   _initialized = false;
  int    _initCount   = 0;
  double _initMax     = 0.0;

  // Adaptive thresholds
  double _spki = 0.0, _npki = 0.0;

  // Peak tracking
  bool   _tracking           = false;
  double _candidatePeak      = 0.0;
  int    _candidateGlobalIdx = -1;
  int    _lastPeakGlobalIdx  = -100; // refractory guard
  int    _lastBeatGlobalIdx  = -1;
  double _lastBeatMwi        = 0.0;  // T-wave reference amplitude
  double _hrSmoothed         = 0.0;
  int    _currentHr          = 0;

  // Searchback: 2-second circular buffer of MWI values
  static const int _sbSize = 1000;
  final _sbBuf = List<double>.filled(1000, 0.0);
  int    _sbHead          = 0;   // next-write position
  int    _samplesSinceBeat = 0;  // samples elapsed since last confirmed beat
  double _meanRrSamples   = 0.0; // exponential-avg RR interval (samples)

  int get currentHr => _currentHr;

  _StreamingPipeline() { _computeCoefficients(); }

  void reset() {
    _hpX1 = _hpX2 = _hpY1 = _hpY2 = 0;
    _lpX1 = _lpX2 = _lpY1 = _lpY2 = 0;
    _ntX1 = _ntX2 = _ntY1 = _ntY2 = 0;
    _diffBuf.fillRange(0, 5, 0.0);
    _mwiBuf.fillRange(0, 75, 0.0);
    _mwiIdx = 0; _mwiSum = 0;
    _initialized = false; _initCount = 0; _initMax = 0;
    _spki = 0; _npki = 0;
    _tracking = false; _candidatePeak = 0; _candidateGlobalIdx = -1;
    _lastPeakGlobalIdx = -100; _lastBeatGlobalIdx = -1;
    _lastBeatMwi = 0; _hrSmoothed = 0; _currentHr = 0;
    _sbBuf.fillRange(0, _sbSize, 0.0);
    _sbHead = 0; _samplesSinceBeat = 0; _meanRrSamples = 0;
  }

  /// Returns global indices of detected R-peaks for this sample.
  /// Normally 0 or 1; occasionally 2 when searchback fires on the same sample
  /// as a new beat.
  List<int> processSample(int rawValue, int globalIdx) {
    // ── Filter chain ─────────────────────────────────────────────────────────
    final xi = rawValue.toDouble();
    var y = _hpB0*xi + _hpB1*_hpX1 + _hpB2*_hpX2 - _hpA1*_hpY1 - _hpA2*_hpY2;
    _hpX2 = _hpX1; _hpX1 = xi; _hpY2 = _hpY1; _hpY1 = y;

    final hpOut = y;
    y = _lpB0*hpOut + _lpB1*_lpX1 + _lpB2*_lpX2 - _lpA1*_lpY1 - _lpA2*_lpY2;
    _lpX2 = _lpX1; _lpX1 = hpOut; _lpY2 = _lpY1; _lpY1 = y;

    final lpOut = y;
    y = lpOut + _ntB1*_ntX1 + _ntX2 - _ntA1*_ntY1 - _ntA2*_ntY2;
    _ntX2 = _ntX1; _ntX1 = lpOut; _ntY2 = _ntY1; _ntY1 = y;

    _diffBuf[4] = _diffBuf[3]; _diffBuf[3] = _diffBuf[2];
    _diffBuf[2] = _diffBuf[1]; _diffBuf[1] = _diffBuf[0];
    _diffBuf[0] = y;
    final dx = (-_diffBuf[4] - 2*_diffBuf[3] + 2*_diffBuf[1] + _diffBuf[0]) / 8.0;

    final sq = dx * dx;
    _mwiSum -= _mwiBuf[_mwiIdx];
    _mwiBuf[_mwiIdx] = sq;
    _mwiSum += sq;
    _mwiIdx = (_mwiIdx + 1) % 75;
    final mwi = _mwiSum / 75.0;

    // ── Searchback buffer ─────────────────────────────────────────────────────
    _sbBuf[_sbHead] = mwi;
    _sbHead = (_sbHead + 1) % _sbSize;
    _samplesSinceBeat++;

    return _detect(mwi, globalIdx);
  }

  List<int> _detect(double mwi, int globalIdx) {
    // ── 2-second initialisation ───────────────────────────────────────────────
    if (!_initialized) {
      if (mwi > _initMax) _initMax = mwi;
      _initCount++;
      if (_initCount >= 1000) {
        _spki = _initMax * 0.5;   // half of max → conservative signal estimate
        _npki = _initMax * 0.05;  // 5 % of max → initial noise floor
        _initialized = true;
      }
      return const [];
    }

    // ── Active threshold decay ──────────────────────────────────────────────
    // If no beat for > 1.5 × meanRR, decay BOTH thresholds at 5.75 %/s (PLOS ONE
    // 2016). Decaying SPKI alone is not enough: a noise burst can inflate NPKI
    // so the threshold 0.75·NPKI + 0.25·SPKI stays locked high. Decaying both
    // brings the whole threshold down so the signal is reacquired; both recover
    // automatically once beats resume.
    final decayGap = _meanRrSamples > 0 ? (_meanRrSamples * 1.5).round() : 700;
    if (_samplesSinceBeat > decayGap) {
      _spki *= 0.99988; // ≈ 5.75 %/s at 500 Hz
      _npki *= 0.99988;
    }

    // ── HR timeout ───────────────────────────────────────────────────────────
    // No beat for > 3 s (1500 samples → HR < 20, implausible): clear HR so the
    // status shows "no value" instead of freezing. Reset the beat reference for
    // a clean re-acquisition when the signal returns.
    if (_lastBeatGlobalIdx >= 0 && _samplesSinceBeat > 1500) {
      _currentHr         = 0;
      _hrSmoothed        = 0;
      _lastBeatGlobalIdx = -1;
    }

    final thr1 = _npki + 0.25 * (_spki - _npki);
    final results = <int>[];

    // ── Searchback ────────────────────────────────────────────────────────────
    // Trigger when no beat for > 1.66 × mean RR (default 1.5 s if RR unknown).
    final expectedGap = _meanRrSamples > 0
        ? (_meanRrSamples * 1.66).round()
        : 750;
    if (_samplesSinceBeat > expectedGap) {
      final sb = _searchback(globalIdx, thr1 * 0.5);
      if (sb != null) {
        results.add(sb);
        // Discard any in-progress tracking so the current sample's elevated MWI
        // (still in the tail of the just-found QRS) is not counted as a second beat.
        _tracking      = false;
        _candidatePeak = 0;
      }
    }

    // ── Normal peak tracking ──────────────────────────────────────────────────
    if (mwi > thr1) {
      if (!_tracking || mwi > _candidatePeak) {
        _candidatePeak      = mwi;
        _candidateGlobalIdx = globalIdx;
      }
      _tracking = true;
    } else if (_tracking) {
      _tracking = false;
      if (_candidateGlobalIdx - _lastPeakGlobalIdx >= 100) {
        // T-wave check: within 360 ms of last beat AND < 50 % of its amplitude.
        final fromLastBeat = _candidateGlobalIdx - _lastBeatGlobalIdx;
        if (_lastBeatGlobalIdx >= 0 &&
            fromLastBeat < 180 &&
            _candidatePeak < 0.5 * _lastBeatMwi) {
          _npki = 0.125 * _candidatePeak + 0.875 * _npki;
        } else {
          // Cap SPKI increase to ×1.5 per beat (Biomed Eng Online) — prevents
          // a single noise spike from inflating the threshold so high that real
          // R-peaks are missed.
          final rawSpki = 0.125 * _candidatePeak + 0.875 * _spki;
          _spki = math.min(rawSpki, _spki * 1.5);
          _confirmBeat(_candidateGlobalIdx, _candidatePeak);
          results.add(_candidateGlobalIdx);
        }
      } else {
        _npki = 0.125 * _candidatePeak + 0.875 * _npki;
      }
      _candidatePeak = 0;
    }

    return results;
  }

  // ── Confirm a beat and update running estimates ───────────────────────────
  void _confirmBeat(int idx, double mwiVal, {bool isSearchback = false}) {
    if (_lastBeatGlobalIdx >= 0) {
      final rr = idx - _lastBeatGlobalIdx;
      // Only use RR intervals ≥ 125 samples (250 ms → < 240 BPM at 500 Hz).
      // Shorter RRs are physiologically implausible and are artefacts of
      // searchback + immediate normal-tracking double-detection.
      if (rr >= 125) {
        _meanRrSamples = _meanRrSamples == 0.0
            ? rr.toDouble()
            : 0.125 * rr + 0.875 * _meanRrSamples;
        final hrInst = (60 * 500 ~/ rr).clamp(40, 200).toDouble();
        // Pure exponential moving average — no hard rejection window.
        // Recovers naturally (~10 beats) even if a bad beat shifts hrSmoothed.
        _hrSmoothed = _hrSmoothed == 0.0
            ? hrInst
            : 0.2 * hrInst + 0.8 * _hrSmoothed;
        _currentHr = _hrSmoothed.round();
      }
    }
    // Searchback peaks may be noise artefacts — don't let them corrupt the
    // T-wave reference amplitude used by the next discrimination check.
    if (!isSearchback) _lastBeatMwi = mwiVal;
    _lastBeatGlobalIdx = idx;
    _lastPeakGlobalIdx = idx;
    _samplesSinceBeat  = 0;
  }

  // ── Search the MWI buffer for the largest peak above halfThreshold ─────────
  int? _searchback(int currentGlobalIdx, double halfThreshold) {
    const refractory = 100; // 200 ms
    final windowEnd  = math.min(_samplesSinceBeat, _sbSize);
    if (windowEnd <= refractory) return null;

    double maxMwi = 0;
    int    bestK  = -1;
    // k = samples before current sample; k=0 → current, k=1 → previous, …
    for (int k = refractory; k < windowEnd; k++) {
      final pos = ((_sbHead - 1 - k) % _sbSize + _sbSize) % _sbSize;
      if (_sbBuf[pos] > maxMwi) { maxMwi = _sbBuf[pos]; bestK = k; }
    }
    if (bestK < 0 || maxMwi <= halfThreshold) return null;

    final peakIdx = currentGlobalIdx - bestK;
    // Searchback peaks use half the SPKI update weight (Pan-Tompkins recommendation)
    // and are capped at ×1.3 — they are less reliable than normally-tracked peaks.
    final rawSpki = 0.0625 * maxMwi + 0.9375 * _spki;
    _spki = math.min(rawSpki, _spki * 1.3);
    _confirmBeat(peakIdx, maxMwi, isSearchback: true);
    // Override the 0 set by _confirmBeat: bestK samples have elapsed since peak.
    _samplesSinceBeat = bestK;
    return peakIdx;
  }

  // ── Filter coefficients (Butterworth bilinear transform) ─────────────────
  void _computeCoefficients() {
    var k    = math.tan(math.pi * 0.5 / _fs);  // HP 0.5 Hz
    var k2   = k * k;
    var sq2k = math.sqrt(2) * k;
    var norm = 1.0 + sq2k + k2;
    _hpB0 = 1.0 / norm; _hpB1 = -2.0 / norm; _hpB2 = _hpB0;
    _hpA1 = 2.0 * (k2 - 1.0) / norm; _hpA2 = (1.0 - sq2k + k2) / norm;

    k = math.tan(math.pi * 40.0 / _fs);        // LP 40 Hz
    k2 = k * k; sq2k = math.sqrt(2) * k; norm = 1.0 + sq2k + k2;
    _lpB0 = k2 / norm; _lpB1 = 2.0 * k2 / norm; _lpB2 = _lpB0;
    _lpA1 = 2.0 * (k2 - 1.0) / norm; _lpA2 = (1.0 - sq2k + k2) / norm;

    final omega0 = 2.0 * math.pi * 50.0 / _fs; // Notch 50 Hz, BW=4 Hz
    final cosW0  = math.cos(omega0);
    final r      = 1.0 - math.pi * 4.0 / _fs;
    _ntB1 = -2.0 * cosW0;
    _ntA1 = -2.0 * r * cosW0;
    _ntA2 = r * r;
  }
}
