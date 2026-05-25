import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/imported_session.dart';
import '../../domain/models/person.dart';
import '../storage/session_storage_service.dart';
import 'ecg_ble_service.dart';
import 'ecg_packet.dart';
import 'ecg_packet_parser.dart';

class RecordingStatus {
  final Duration elapsed;
  final int sampleCount;
  final int currentHr;
  final bool connected;

  const RecordingStatus({
    required this.elapsed,
    required this.sampleCount,
    required this.currentHr,
    required this.connected,
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
    _rawFile!.writeFromSync(_serializePacket(packet));
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
      _hrFile!.writeFromSync(bd.buffer.asUint8List());
    }

    // Streaming R-peak detection — one sample at a time.
    for (int i = 0; i < packet.samples.length; i++) {
      final gIdx = _globalSampleIdx + i;
      final peak = _pipeline.processSample(packet.samples[i], gIdx);
      if (peak != null) _rPeakIndices.add(peak);
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

/// Stateful single-sample ECG processing pipeline:
/// HP filter → LP filter → Notch filter → differentiate → square →
/// moving-window integrate → adaptive threshold.
///
/// Matches [EcgFilter] coefficients exactly so recorded and displayed signals
/// are processed identically.
class _StreamingPipeline {
  static const double _fs = 500.0;

  // IIR filter coefficients (computed once in reset()).
  late double _hp_b0, _hp_b1, _hp_b2, _hp_a1, _hp_a2;
  late double _lp_b0, _lp_b1, _lp_b2, _lp_a1, _lp_a2;
  late double _nt_b1, _nt_a1, _nt_a2; // b0=b2=1 for notch

  // Filter state
  double _hp_x1 = 0, _hp_x2 = 0, _hp_y1 = 0, _hp_y2 = 0;
  double _lp_x1 = 0, _lp_x2 = 0, _lp_y1 = 0, _lp_y2 = 0;
  double _nt_x1 = 0, _nt_x2 = 0, _nt_y1 = 0, _nt_y2 = 0;

  // Pan-Tompkins state
  final _diffBuf = List<double>.filled(5, 0.0);
  final _mwiBuf  = List<double>.filled(75, 0.0); // 150 ms at 500 Hz
  int    _mwiIdx = 0;
  double _mwiSum = 0.0;

  // Adaptive threshold
  bool   _initialized = false;
  int    _initCount   = 0;
  double _initMax     = 0.0;
  double _initSum     = 0.0;
  double _spki = 0.0, _npki = 0.0;

  // Peak tracking
  bool   _tracking           = false;
  double _candidatePeak      = 0.0;
  int    _candidateGlobalIdx = -1;
  int    _lastPeakGlobalIdx  = -100; // refractory 200 ms = 100 samples
  int    _lastBeatGlobalIdx  = -1;
  double _hrSmoothed         = 0.0;
  int    _currentHr          = 0;

  int get currentHr => _currentHr;

  _StreamingPipeline() { _computeCoefficients(); }

  void reset() {
    _hp_x1 = _hp_x2 = _hp_y1 = _hp_y2 = 0;
    _lp_x1 = _lp_x2 = _lp_y1 = _lp_y2 = 0;
    _nt_x1 = _nt_x2 = _nt_y1 = _nt_y2 = 0;
    _diffBuf.fillRange(0, 5, 0.0);
    _mwiBuf.fillRange(0, 75, 0.0);
    _mwiIdx = 0; _mwiSum = 0;
    _initialized = false; _initCount = 0; _initMax = 0; _initSum = 0;
    _spki = 0; _npki = 0;
    _tracking = false; _candidatePeak = 0; _candidateGlobalIdx = -1;
    _lastPeakGlobalIdx = -100; _lastBeatGlobalIdx = -1;
    _hrSmoothed = 0; _currentHr = 0;
  }

  /// Returns the global sample index of a detected R-peak, or null.
  int? processSample(int rawValue, int globalIdx) {
    // 1. HP 0.5 Hz
    final xi = rawValue.toDouble();
    var y = _hp_b0*xi + _hp_b1*_hp_x1 + _hp_b2*_hp_x2 - _hp_a1*_hp_y1 - _hp_a2*_hp_y2;
    _hp_x2 = _hp_x1; _hp_x1 = xi; _hp_y2 = _hp_y1; _hp_y1 = y;

    // 2. LP 40 Hz
    final hpOut = y;
    y = _lp_b0*hpOut + _lp_b1*_lp_x1 + _lp_b2*_lp_x2 - _lp_a1*_lp_y1 - _lp_a2*_lp_y2;
    _lp_x2 = _lp_x1; _lp_x1 = hpOut; _lp_y2 = _lp_y1; _lp_y1 = y;

    // 3. Notch 50 Hz  (b0=b2=1)
    final lpOut = y;
    y = lpOut + _nt_b1*_nt_x1 + _nt_x2 - _nt_a1*_nt_y1 - _nt_a2*_nt_y2;
    _nt_x2 = _nt_x1; _nt_x1 = lpOut; _nt_y2 = _nt_y1; _nt_y1 = y;

    // 4. Differentiate (5-point Pan-Tompkins)
    _diffBuf[4] = _diffBuf[3]; _diffBuf[3] = _diffBuf[2];
    _diffBuf[2] = _diffBuf[1]; _diffBuf[1] = _diffBuf[0];
    _diffBuf[0] = y;
    final dx = (-_diffBuf[4] - 2*_diffBuf[3] + 2*_diffBuf[1] + _diffBuf[0]) / 8.0;

    // 5. Square + 6. Moving-window integrate (150 ms)
    final sq = dx * dx;
    _mwiSum -= _mwiBuf[_mwiIdx];
    _mwiBuf[_mwiIdx] = sq;
    _mwiSum += sq;
    _mwiIdx = (_mwiIdx + 1) % 75;
    final mwi = _mwiSum / 75.0;

    return _detectPeak(mwi, globalIdx);
  }

  int? _detectPeak(double mwi, int globalIdx) {
    // 2-second initialisation window
    if (!_initialized) {
      if (mwi > _initMax) _initMax = mwi;
      _initSum += mwi;
      _initCount++;
      if (_initCount >= 1000) {
        _spki = _initMax / 3.0;
        _npki = (_initSum / _initCount) / 2.0;
        _initialized = true;
      }
      return null;
    }

    final threshold = _npki + 0.25 * (_spki - _npki);

    if (mwi > threshold) {
      if (!_tracking || mwi > _candidatePeak) {
        _candidatePeak      = mwi;
        _candidateGlobalIdx = globalIdx;
      }
      _tracking = true;
    } else if (_tracking) {
      _tracking = false;
      if (_candidateGlobalIdx - _lastPeakGlobalIdx >= 100) {
        _spki = 0.125 * _candidatePeak + 0.875 * _spki;
        int? result;
        if (_lastBeatGlobalIdx >= 0) {
          final rrSamples = _candidateGlobalIdx - _lastBeatGlobalIdx;
          if (rrSamples > 0) {
            final hrInst = (60 * 500 ~/ rrSamples).clamp(30, 220);
            if (_hrSmoothed == 0) {
              _hrSmoothed = hrInst.toDouble();
            } else if ((hrInst - _hrSmoothed).abs() <= 30) {
              _hrSmoothed = 0.2 * hrInst + 0.8 * _hrSmoothed;
            }
            _currentHr = _hrSmoothed.round();
          }
        }
        _lastBeatGlobalIdx  = _candidateGlobalIdx;
        _lastPeakGlobalIdx  = _candidateGlobalIdx;
        result = _candidateGlobalIdx;
        _candidatePeak = 0;
        return result;
      } else {
        _npki = 0.125 * _candidatePeak + 0.875 * _npki;
        _candidatePeak = 0;
      }
    }
    return null;
  }

  void _computeCoefficients() {
    // HP 0.5 Hz (identical to EcgFilter)
    var k    = math.tan(math.pi * 0.5 / _fs);
    var k2   = k * k;
    var sq2k = math.sqrt(2) * k;
    var norm = 1.0 + sq2k + k2;
    _hp_b0 = 1.0 / norm; _hp_b1 = -2.0 / norm; _hp_b2 = _hp_b0;
    _hp_a1 = 2.0 * (k2 - 1.0) / norm; _hp_a2 = (1.0 - sq2k + k2) / norm;

    // LP 40 Hz
    k = math.tan(math.pi * 40.0 / _fs);
    k2 = k * k; sq2k = math.sqrt(2) * k; norm = 1.0 + sq2k + k2;
    _lp_b0 = k2 / norm; _lp_b1 = 2.0 * k2 / norm; _lp_b2 = _lp_b0;
    _lp_a1 = 2.0 * (k2 - 1.0) / norm; _lp_a2 = (1.0 - sq2k + k2) / norm;

    // Notch 50 Hz, BW=4 Hz
    final omega0 = 2.0 * math.pi * 50.0 / _fs;
    final cosW0  = math.cos(omega0);
    final r      = 1.0 - math.pi * 4.0 / _fs;
    _nt_b1 = -2.0 * cosW0;
    _nt_a1 = -2.0 * r * cosW0;
    _nt_a2 = r * r;
  }
}
