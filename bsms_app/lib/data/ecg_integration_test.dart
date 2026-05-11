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

  /// Tests packet parsing with real ESP32 device data.
  void testRealEsp32Data() {
    print('\n🧪 Testing with real ESP32 device data...');

    // Real ESP32 packet data (hex strings from device)
    final esp32Packets = [
      // Packet 1
      '40 E2 01 00 48 14 00 90 33 9F 33 96 33 A1 33 96 33 84 33 82 34 55 35 0B 36 8F 36 B3 36 98 36 28 36 63 35 87 34 84 33 7C 33 8F 33 8D 33 97 33',
      // Packet 2
      '68 E2 01 00 48 14 00 A6 33 95 33 97 33 8F 33 7B 33 88 33 87 33 8C 33 A2 33 99 33 9B 33 9A 33 83 33 4E 34 DF 34 10 35 F2 34 5F 34 9A 33 A4 33',
      // Packet 3
      '90 E2 01 00 48 14 00 8E 33 8B 33 31 31 BA 52 31 6C 02 4B BB 24 D6 2B A4 31 90 33 91 33 7C 33 84 33 8D 33 8A 33 A0 33 9F 33 96 33 9B 33 85 33',
    ];

    for (int i = 0; i < esp32Packets.length; i++) {
      print('\n📦 Testing ESP32 Packet ${i + 1}...');

      try {
        // Convert hex string to Uint8List
        final data = _hexStringToUint8List(esp32Packets[i]);

        // Parse the packet
        final packet = _parser.parse(data);

        print('✅ Packet ${i + 1} parsed successfully:');
        print('   Timestamp: ${packet.timestamp} (${packet.timestamp.millisecondsSinceEpoch} ms)');
        print('   Heart Rate: ${packet.heartRate} BPM');
        print('   Sample Count: ${packet.samples.length}');
        print('   Status Flags: 0x${packet.flags.toRadixString(16).padLeft(2, '0')}');

        // Convert to individual samples
        final samples = _parser.packetToSamples(packet);
        print('✅ Converted to ${samples.length} individual samples');
        print('   Sample range: ${samples.first.value} - ${samples.last.value}');
        print('   Time range: ${samples.first.timestampMs} - ${samples.last.timestampMs} ms');

        // Validate sample count
        if (packet.samples.length != 20) {
          print('❌ Expected 20 samples, got ${packet.samples.length}');
        }

        // Validate timestamps are sequential (2ms intervals)
        for (int j = 1; j < samples.length; j++) {
          final expectedTime = samples[j-1].timestampMs + 2;
          if (samples[j].timestampMs != expectedTime) {
            print('❌ Timestamp discontinuity at sample $j: expected $expectedTime, got ${samples[j].timestampMs}');
          }
        }

      } catch (e) {
        print('❌ Failed to parse ESP32 packet ${i + 1}: $e');
      }
    }

    print('\n✅ Real ESP32 data validation completed');
  }

  /// Converts a hex string (space-separated bytes) to Uint8List.
  Uint8List _hexStringToUint8List(String hexString) {
    final hexBytes = hexString.split(' ').where((s) => s.isNotEmpty).toList();
    final bytes = <int>[];

    for (final hexByte in hexBytes) {
      bytes.add(int.parse(hexByte, radix: 16));
    }

    return Uint8List.fromList(bytes);
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
    testRealEsp32Data();
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