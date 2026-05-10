import 'dart:async';
import 'dart:typed_data';
import '../domain/ecg_sample.dart';
import 'ble/ecg_packet.dart';
import 'ble/ecg_packet_parser.dart';
import 'buffer/ecg_ring_buffer.dart';

/// Mock implementation of EcgDataPipeline for testing without BLE.
class MockEcgDataPipeline {
  final EcgPacketParser _parser;
  final EcgRingBuffer _buffer;
  final StreamController<List<EcgSample>> _sampleStreamController = StreamController<List<EcgSample>>.broadcast();

  Timer? _emissionTimer;

  MockEcgDataPipeline(this._parser, this._buffer);

  Stream<List<EcgSample>> get sampleStream => _sampleStreamController.stream;

  /// Processes an incoming ECG packet (public for testing).
  void processPacket(EcgPacket packet) {
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
  void startEmission() {
    // Emit samples every 100ms for smooth 10Hz UI updates
    _emissionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
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

  /// Stops the mock pipeline.
  void stop() {
    _emissionTimer?.cancel();
    _sampleStreamController.close();
    _buffer.clear();
    print('Mock pipeline stopped');
  }

  /// Returns current buffer statistics.
  Map<String, dynamic> getBufferStats() {
    return {
      'bufferSize': _buffer.count,
      'bufferCapacity': _buffer.capacity,
      'isBufferFull': _buffer.isFull,
      'isBleConnected': false, // Mock always disconnected
    };
  }
}

/// Integration test for the complete ECG data pipeline.
/// Tests BLE → Parser → Ring Buffer → UI Stream flow.
class EcgIntegrationTest {
  late EcgPacketParser _parser;
  late EcgRingBuffer _buffer;
  late MockEcgDataPipeline _pipeline;

  StreamSubscription<List<EcgSample>>? _sampleSubscription;
  final List<List<EcgSample>> _receivedSamples = [];

  /// Initializes components WITHOUT BLE service for testing.
  Future<void> initializeWithoutBle() async {
    print('🔧 Initializing ECG integration test components (no BLE)...');

    _parser = EcgPacketParser();
    _buffer = EcgRingBuffer();

    // Create a mock pipeline that doesn't use BLE
    _pipeline = MockEcgDataPipeline(_parser, _buffer);

    print('✅ Components initialized');
  }

  /// Tests packet parsing with sample data.
  void testPacketParsing() {
    print('\n🧪 Testing packet parsing...');

    // Create a sample 47-byte packet (little-endian)
    // Format: <IBBB20H
    final data = Uint8List(47);
    final byteData = ByteData.sublistView(data);

    // Timestamp: 1000000 ms
    byteData.setUint32(0, 1000000, Endian.little);

    // Heart rate: 75 BPM
    byteData.setUint8(4, 75);

    // Sample count: 20
    byteData.setUint8(5, 20);

    // Flags: 0 (no lead-off)
    byteData.setUint8(6, 0);

    // 20 ECG samples: 1000, 1001, 1002, ... 1019
    for (int i = 0; i < 20; i++) {
      byteData.setUint16(7 + (i * 2), 1000 + i, Endian.little);
    }

    try {
      final packet = _parser.parse(data);
      print('✅ Packet parsed successfully:');
      print('   Timestamp: ${packet.timestamp}');
      print('   Heart Rate: ${packet.heartRate} BPM');
      print('   Flags: ${packet.flags}');
      print('   Samples: ${packet.samples.length} values');

      final samples = _parser.packetToSamples(packet);
      print('✅ Converted to ${samples.length} individual samples');
      print('   First sample: ${samples.first}');
      print('   Last sample: ${samples.last}');

    } catch (e) {
      print('❌ Packet parsing failed: $e');
    }
  }

  /// Tests ring buffer functionality.
  void testRingBuffer() {
    print('\n🧪 Testing ring buffer...');

    // Clear buffer first
    _buffer.clear();

    // Add some test samples
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 10; i++) {
      final sample = EcgSample(
        value: 1000 + i,
        timestampMs: now + (i * 2),
      );
      _buffer.write(sample);
    }

    print('✅ Added 10 samples to buffer');
    print('   Buffer size: ${_buffer.count}/${_buffer.capacity}');

    // Test peeking
    final allSamples = _buffer.peekAll();
    print('✅ Peeked ${allSamples.length} samples');

    final last5 = _buffer.peekLast(5);
    print('✅ Peeked last 5 samples: ${last5.map((s) => s.value).toList()}');

    // Test reading
    final firstRead = _buffer.read();
    print('✅ Read first sample: $firstRead');
    print('   Buffer size after read: ${_buffer.count}/${_buffer.capacity}');
  }

  /// Tests the complete data pipeline with simulated BLE data.
  Future<void> testDataPipeline() async {
    print('\n🧪 Testing complete data pipeline...');

    // Subscribe to sample stream
    _sampleSubscription = _pipeline.sampleStream.listen(
      (samples) {
        _receivedSamples.add(samples);
        print('📊 Received ${samples.length} samples in UI stream');
        if (samples.isNotEmpty) {
          print('   Sample range: ${samples.first.value} - ${samples.last.value}');
        }
      },
      onError: (error) {
        print('❌ Pipeline error: $error');
      },
    );

    // Start sample emission
    _pipeline.startEmission();

    // Simulate BLE packets
    print('📡 Simulating BLE packet stream...');

    final simulatedPackets = _createSimulatedPackets(5);
    for (final packet in simulatedPackets) {
      // Simulate packet arrival
      _pipeline.processPacket(packet);

      // Wait a bit between packets (like real BLE timing)
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Wait for pipeline to process and emit
    await Future.delayed(const Duration(milliseconds: 300));

    print('✅ Pipeline test completed');
    print('📈 Total sample batches received: ${_receivedSamples.length}');
    print('📊 Total samples processed: ${_receivedSamples.expand((batch) => batch).length}');

    // Check buffer stats
    final stats = _pipeline.getBufferStats();
    print('🗂️  Buffer stats: $stats');
  }

  /// Creates simulated ECG packets for testing.
  List<EcgPacket> _createSimulatedPackets(int count) {
    final packets = <EcgPacket>[];
    final baseTime = DateTime.now();

    for (int p = 0; p < count; p++) {
      final packetTime = baseTime.add(Duration(milliseconds: p * 40)); // 40ms between packets
      final samples = <int>[];

      // Create 20 samples per packet (500Hz * 40ms = 20 samples)
      for (int s = 0; s < 20; s++) {
        // Simulate ECG-like waveform with some variation
        final baseValue = 2048; // Mid-range ADC value
        final variation = (s % 10 - 5) * 50; // Simple waveform pattern
        samples.add(baseValue + variation + (p * 10)); // Add packet offset
      }

      packets.add(EcgPacket(
        timestamp: packetTime,
        heartRate: 72 + p, // Varying heart rate
        flags: p % 2, // Alternate flags
        samples: samples,
      ));
    }

    return packets;
  }

  /// Runs all integration tests.
  Future<void> runAllTests() async {
    print('🚀 Starting ECG Integration Tests\n');

    await initializeWithoutBle();
    testPacketParsing();
    testRingBuffer();
    await testDataPipeline();

    print('\n🎉 All integration tests completed!');
  }

  /// Cleans up test resources.
  void dispose() {
    _sampleSubscription?.cancel();
    _pipeline.stop();
    print('🧹 Test resources cleaned up');
  }
}