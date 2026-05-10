import 'dart:typed_data';
import 'ecg_packet.dart';
import '../../domain/ecg_sample.dart';

/// Parses raw 47-byte BLE packets from ESP32 into structured EcgPacket objects.
/// 
/// Handles:
/// - Validation of packet size and structure
/// - Little-endian decoding of packet fields (timestamp, HR, flags, samples)
/// - Reconstruction of individual sample timestamps at 2ms intervals (500Hz)
/// - Conversion to domain model objects (EcgSample) with absolute timestamps
/// 
/// Packet format (47 bytes total, little-endian):
/// Offset  Size  Type        Field
/// 0       4     uint32      timestamp_ms (ESP32 boot time)
/// 4       1     uint8       hr_avg (BPM, 0 = not calculated)
/// 5       1     uint8       sample_count (always 20)
/// 6       1     uint8       status_flags (lead-off indicators)
/// 7       40    uint16[20]  samples[] (12-bit ADC values)
class EcgPacketParser {
  static const int packetSize = 47;
  static const int samplesPerPacket = 20;
  static const int sampleIntervalMs = 2; // 500Hz = 2ms per sample

  /// Parses a 47-byte raw packet from BLE into an EcgPacket object.
  /// 
  /// Throws ArgumentError if:
  /// - Packet size is not exactly 47 bytes
  /// - Sample count is not 20
  /// 
  /// Returns: EcgPacket with all fields extracted and validated
  EcgPacket parse(List<int> data) {
    if (data.length != packetSize) {
      throw ArgumentError('Invalid ECG packet size: ${data.length}, expected $packetSize');
    }

    // Create ByteData view for efficient parsing
    final byteData = ByteData.sublistView(Uint8List.fromList(data));

    // Parse packet fields (little-endian)
    final timestampMs = byteData.getUint32(0, Endian.little);
    final heartRate = byteData.getUint8(4);
    final sampleCount = byteData.getUint8(5); // Should be 20
    final flags = byteData.getUint8(6);

    // Parse 20 ECG samples (uint16, little-endian)
    final samples = <int>[];
    for (int i = 0; i < samplesPerPacket; i++) {
      final sample = byteData.getUint16(7 + (i * 2), Endian.little);
      samples.add(sample);
    }

    // Validate sample count
    if (sampleCount != samplesPerPacket) {
      throw ArgumentError('Invalid sample count: $sampleCount, expected $samplesPerPacket');
    }

    // Create DateTime from timestamp
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);

    return EcgPacket(
      timestamp: timestamp,
      heartRate: heartRate,
      flags: flags,
      samples: samples,
    );
  }

  /// Converts packet samples to individual EcgSample objects with reconstructed timestamps
  List<EcgSample> packetToSamples(EcgPacket packet) {
    final samples = <EcgSample>[];
    final baseTimestamp = packet.timestamp.millisecondsSinceEpoch;

    for (int i = 0; i < packet.samples.length; i++) {
      final sampleTimestamp = baseTimestamp + (i * sampleIntervalMs);
      samples.add(EcgSample(
        value: packet.samples[i],
        timestampMs: sampleTimestamp,
      ));
    }

    return samples;
  }
}
