/// Represents a parsed ECG data packet received from the ESP32 device.
/// 
/// This is the output of EcgPacketParser.parse() and contains all fields
/// extracted from the 47-byte BLE packet according to the EKG-Holter specification.
class EcgPacket {
  /// Timestamp of the FIRST sample in this packet (boot-relative milliseconds).
  /// Per-sample times: timestamp + i*2ms (i = 0..19) at 500Hz sampling rate.
  final DateTime timestamp;
  
  /// Smoothed heart rate in BPM from device firmware.
  /// Value is 0 if not yet calculated by the device.
  final int heartRate;
  
  /// Status flags from packet byte 6.
  /// bit 0 (0x01): LO+ lead-off detected
  /// bit 1 (0x02): LO- lead-off detected
  /// bits 2-7: reserved (always 0)
  final int flags;
  
  /// 20 raw ECG samples (12-bit ADC values, range 0..4095).
  /// Baseline approximately 2048, sample rate 500Hz.
  final List<int> samples;

  EcgPacket({
    required this.timestamp,
    required this.heartRate,
    required this.flags,
    required this.samples,
  });
}
