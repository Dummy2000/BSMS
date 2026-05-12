import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service to process incoming binary ECG data and manage storage.
class EcgDataProcessor {
  // Stream for real-time UI updates
  final _signalStreamController = StreamController<int>.broadcast();
  Stream<int> get signalStream => _signalStreamController.stream;

  // Internal buffer for CSV saving
  List<String> _csvBuffer = [];
  
  /// Processes raw 47-byte packets.
  void handleRawData(Uint8List rawBytes) {
    if (rawBytes.length != 47) return;

    final ByteData data = ByteData.sublistView(rawBytes);
    
    // Extract Timestamp (4 bytes, Little Endian)
    final int timestamp = data.getUint32(0, Endian.little);

    // Extract 21 samples and add to stream and buffer
    for (int i = 0; i < 21; i++) {
      int offset = 4 + (i * 2);
      int value = data.getInt16(offset, Endian.little);
      
      _signalStreamController.add(value);
      _csvBuffer.add("$timestamp,$value");
    }

    // Auto-save to file if buffer grows (e.g., every 500 samples)
    if (_csvBuffer.length >= 500) {
      _saveToCsv();
    }
  }

  /// Saves the current buffer to a CSV file in the app's document directory.
  Future<void> _saveToCsv() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ecg_data_log.csv');
      
      final String dataToSave = _csvBuffer.join("\n") + "\n";
      await file.writeAsString(dataToSave, mode: FileMode.append);
      
      _csvBuffer.clear();
      print("Data saved to: ${file.path}");
    } catch (e) {
      print("Error saving CSV: $e");
    }
  }

  void dispose() {
    _signalStreamController.close();
  }
}
