import 'dart:async';
import '../domain/ecg_sample.dart';
import 'ble/ecg_ble_service.dart';
import 'ble/ecg_packet.dart';
import 'ble/ecg_packet_parser.dart';
import 'buffer/ecg_ring_buffer.dart';

/// Data pipeline service that connects BLE → Parser → Ring Buffer → UI.
/// Manages the flow of ECG data from device to application.
class EcgDataPipeline {
  final EcgBleService _bleService;
  final EcgPacketParser _parser;
  final EcgRingBuffer _buffer;

  StreamSubscription<EcgPacket>? _packetSubscription;
  final StreamController<List<EcgSample>> _sampleStreamController = StreamController<List<EcgSample>>.broadcast();

  EcgDataPipeline(this._bleService, this._parser, this._buffer);

  /// Stream of ECG samples for UI consumption.
  /// Emits lists of recent samples at regular intervals for smooth visualization.
  Stream<List<EcgSample>> get sampleStream => _sampleStreamController.stream;

  /// Starts the data pipeline.
  Future<void> start() async {
    // Start BLE service
    await _bleService.start();

    // Subscribe to BLE packets and process them
    _packetSubscription = _bleService.ecgPackets.listen(
      _processPacket,
      onError: (error) {
        print('Pipeline error: $error');
        _sampleStreamController.addError(error);
      },
      onDone: () {
        print('BLE packet stream ended');
        _sampleStreamController.close();
      },
    );

    // Start periodic emission of samples for UI
    _startSampleEmission();
  }

  /// Processes an incoming ECG packet.
  /// Public for testing purposes.
  void processPacket(EcgPacket packet) {
    _processPacket(packet);
  }

  /// Internal packet processing method.
  void _processPacket(EcgPacket packet) {
    try {
      // Parse packet into individual samples with reconstructed timestamps
      final samples = _parser.packetToSamples(packet);

      // Add samples to ring buffer
      for (final sample in samples) {
        _buffer.write(sample);
      }

      print('Processed packet with ${samples.length} samples, buffer size: ${_buffer.count}');
    } catch (e) {
      print('Failed to process ECG packet: $e');
      _sampleStreamController.addError('Packet processing error: $e');
    }
  }

  /// Starts periodic emission of recent samples to UI.
  void _startSampleEmission() {
    // Emit samples every 100ms for smooth 10Hz UI updates
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_sampleStreamController.isClosed) {
        timer.cancel();
        return;
      }

      try {
        // Get recent samples (last 500ms worth at 500Hz = 250 samples)
        final recentSamples = _buffer.peekLast(250);
        if (recentSamples.isNotEmpty) {
          _sampleStreamController.add(recentSamples);
        }
      } catch (e) {
        print('Error emitting samples: $e');
        _sampleStreamController.addError(e);
      }
    });
  }

  /// Stops the data pipeline.
  void stop() {
    _packetSubscription?.cancel();
    _sampleStreamController.close();
    _bleService.stop();
    _buffer.clear();

    print('Data pipeline stopped');
  }

  /// Returns current buffer statistics.
  Map<String, dynamic> getBufferStats() {
    return {
      'bufferSize': _buffer.count,
      'bufferCapacity': _buffer.capacity,
      'isBufferFull': _buffer.isFull,
      'isBleConnected': _bleService.isConnected,
    };
  }
}