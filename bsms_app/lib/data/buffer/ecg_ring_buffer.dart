import '../../domain/ecg_sample.dart';
import 'buffer_config.dart';

/// Ring buffer for storing ECG samples with fixed capacity.
/// When full, oldest samples are overwritten by new ones.
/// Provides efficient storage for real-time ECG data streaming.
class EcgRingBuffer {
  final List<EcgSample?> _buffer;
  int _writeIndex = 0;
  int _readIndex = 0;
  int _count = 0;
  bool _isFull = false;

  EcgRingBuffer()
      : _buffer = List<EcgSample?>.filled(BufferConfig.maxSamples, null);

  /// Adds a new ECG sample to the buffer.
  /// If buffer is full, oldest sample is overwritten.
  void write(EcgSample sample) {
    _buffer[_writeIndex] = sample;
    _writeIndex = (_writeIndex + 1) % BufferConfig.maxSamples;

    if (_isFull) {
      // Buffer was already full, so read index moves with write index
      _readIndex = (_readIndex + 1) % BufferConfig.maxSamples;
    } else {
      _count++;
      if (_count >= BufferConfig.maxSamples) {
        _isFull = true;
      }
    }

    // Clean up old samples beyond maximum age
    _cleanupOldSamples();
  }

  /// Reads the next available sample from the buffer.
  /// Returns null if buffer is empty.
  EcgSample? read() {
    if (_count == 0) return null;

    final sample = _buffer[_readIndex];
    _readIndex = (_readIndex + 1) % BufferConfig.maxSamples;
    _count--;

    if (_count < BufferConfig.maxSamples) {
      _isFull = false;
    }

    return sample;
  }

  /// Returns all available samples without removing them from buffer.
  /// Useful for visualization that needs to access recent history.
  List<EcgSample> peekAll() {
    final samples = <EcgSample>[];
    int index = _readIndex;
    int remaining = _count;

    while (remaining > 0) {
      final sample = _buffer[index];
      if (sample != null) {
        samples.add(sample);
      }
      index = (index + 1) % BufferConfig.maxSamples;
      remaining--;
    }

    return samples;
  }

  /// Returns the last N samples without removing them.
  /// Useful for real-time display of recent ECG data.
  List<EcgSample> peekLast(int count) {
    if (count <= 0) return [];
    if (count >= _count) return peekAll();

    final samples = <EcgSample>[];
    int index = (_writeIndex - count + BufferConfig.maxSamples) % BufferConfig.maxSamples;

    for (int i = 0; i < count; i++) {
      final sample = _buffer[index];
      if (sample != null) {
        samples.add(sample);
      }
      index = (index + 1) % BufferConfig.maxSamples;
    }

    return samples;
  }

  /// Clears all samples from the buffer.
  void clear() {
    for (int i = 0; i < _buffer.length; i++) {
      _buffer[i] = null;
    }
    _writeIndex = 0;
    _readIndex = 0;
    _count = 0;
    _isFull = false;
  }

  /// Returns the current number of samples in the buffer.
  int get count => _count;

  /// Returns true if the buffer is empty.
  bool get isEmpty => _count == 0;

  /// Returns true if the buffer is full.
  bool get isFull => _isFull;

  /// Returns the buffer capacity.
  int get capacity => BufferConfig.maxSamples;

  /// Removes samples older than the maximum allowed age.
  void _cleanupOldSamples() {
    if (_count == 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = BufferConfig.maxSampleAgeMs;

    // Start from read index and remove old samples
    while (_count > 0) {
      final sample = _buffer[_readIndex];
      if (sample == null || (now - sample.timestampMs) > maxAge) {
        // Remove this sample
        _buffer[_readIndex] = null;
        _readIndex = (_readIndex + 1) % BufferConfig.maxSamples;
        _count--;

        if (_count < BufferConfig.maxSamples) {
          _isFull = false;
        }
      } else {
        // Sample is still valid, stop cleaning
        break;
      }
    }
  }
}