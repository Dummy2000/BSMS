import 'dart:typed_data';

import '../../domain/ecg_sample.dart';
import '../../domain/heart_rate_value.dart';

class EcgPacket {
  final List<EcgSample> samples;
  final HeartRateValue? heartRate;
  final bool leadOff;

  EcgPacket({
    required this.samples,
    required this.heartRate,
    required this.leadOff,
  });
}

class EcgPacketParser {
  static const int packetSize = 47;
  static const int samplesPerPacket = 20;
  static const int sampleIntervalMs = 2; // 500 Hz

  EcgPacket parse(Uint8List data) {
    if (data.length != packetSize) {
      throw Exception("Invalid ECG packet size: ${data.length}");
    }

    final byteData = ByteData.sublistView(data);

    // Header fields
    final int timestampMs = byteData.getUint32(0, Endian.little);
    final int hrAvg = byteData.getUint8(4);
    final int sampleCount = byteData.getUint8(5);
    final int statusFlags = byteData.getUint8(6);

    // Lead-off detection (bit 0 or bit 1)
    final bool leadOff = (statusFlags & 0x03) != 0;

    // Samples
    final List<EcgSample> samples = [];
    int offset = 7;

    for (int i = 0; i < sampleCount; i++) {
      final int raw = byteData.getUint16(offset, Endian.little);
      final int ts = timestampMs + i * sampleIntervalMs;

      samples.add(EcgSample(value: raw, timestampMs: ts));

      offset += 2;
    }

    // Heart rate (0 = not available)
    HeartRateValue? hr;
    if (hrAvg > 0) {
      hr = HeartRateValue(bpm: hrAvg, timestampMs: timestampMs);
    }

    return EcgPacket(
      samples: samples,
      heartRate: hr,
      leadOff: leadOff,
    );
  }
}
