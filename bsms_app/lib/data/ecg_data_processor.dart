import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Service to process incoming binary ECG data and manage storage.
///
/// This service parses raw 47-byte ECG packets, emits sample values for
/// UI consumption and saves buffered data periodically to a CSV file.
class EcgDataProcessor {
  static const int packetSize = 47;
  static const int sampleCount = 20;
  static const int samplesOffset = 7;
  static const int saveThreshold = 500;

  // Stream for real-time UI updates
  final _signalStreamController = StreamController<int>.broadcast();
  Stream<int> get signalStream => _signalStreamController.stream;

  // Internal buffer for CSV saving
  final List<String> _csvBuffer = [];

  /// Processes raw 47-byte packets.
  void handleRawData(Uint8List rawBytes) {
    if (rawBytes.length != packetSize) {
      print('Ignored raw packet with invalid length: ${rawBytes.length}');
      return;
    }

    final data = ByteData.sublistView(rawBytes);

    // Extract timestamp (4 bytes, Little Endian)
    final int timestamp = data.getUint32(0, Endian.little);

    // Parse 20 samples and add to stream and buffer
    for (int i = 0; i < sampleCount; i++) {
      final int offset = samplesOffset + (i * 2);
      final int value = data.getInt16(offset, Endian.little);

      if (!_signalStreamController.isClosed) {
        _signalStreamController.add(value);
      }

      _csvBuffer.add('$timestamp,$value');
    }

    if (_csvBuffer.length >= saveThreshold) {
      _saveToCsv();
    }
  }

  /// Saves the current buffer to a CSV file in the app's document directory.
  Future<void> _saveToCsv() async {
    if (_csvBuffer.isEmpty) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ecg_data_log.csv');
      final String dataToSave = '${_csvBuffer.join('\n')}\n';
      await file.writeAsString(dataToSave, mode: FileMode.append, flush: true);
      _csvBuffer.clear();
      print('Data saved to: ${file.path}');
    } catch (e) {
      print('Error saving CSV: $e');
    }
  }

  /// Force-save any pending CSV data.
  Future<void> flushPendingData() async {
    await _saveToCsv();
  }

  /// Dispose the processor and close internal streams.
  void dispose() {
    if (!_signalStreamController.isClosed) {
      _signalStreamController.close();
    }
  }
}
