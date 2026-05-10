/// Represents a heart rate measurement at a specific point in time.
/// 
/// Contains both the calculated BPM value and the timestamp when it was measured,
/// allowing temporal tracking of HR changes throughout a session.
class HeartRateValue {
  /// Heart rate in beats per minute (BPM).
  /// Calculated from R-peak intervals or provided by device firmware.
  final int bpm;
  
  /// Timestamp in milliseconds when this heart rate was calculated.
  /// Enables time-series analysis and trend visualization.
  final int timestampMs;

  HeartRateValue({
    required this.bpm,
    required this.timestampMs,
  });
}
