/// Configuration for ECG data buffering.
/// These values determine the ring buffer capacity and behavior.
class BufferConfig {
  /// Maximum number of ECG samples to store in the ring buffer.
  /// At 500Hz sampling rate, this provides ~4 seconds of history.
  static const int maxSamples = 2000;

  /// Number of samples to keep as "safe" margin before oldest data gets overwritten.
  /// This prevents losing data that's still being processed for display.
  static const int safeMarginSamples = 100;

  /// Maximum age of samples to keep (in milliseconds).
  /// Older samples are automatically discarded.
  static const int maxSampleAgeMs = 10000; // 10 seconds
}