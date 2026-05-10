/// Represents a single ECG sample from the device.
/// 
/// Each sample contains the raw ADC value and precise timestamp for reconstruction
/// of the signal during visualization or signal processing.
class EcgSample {
  /// Raw 12-bit ADC value from ESP32 (range 0..4095).
  /// Baseline is approximately 2048 (mid-range).
  final int value;
  
  /// Absolute timestamp in milliseconds since sample capture.
  /// Used to reconstruct signal timing during real-time or post-processing analysis.
  final int timestampMs;

  EcgSample({
    required this.value,
    required this.timestampMs,
  });
}
