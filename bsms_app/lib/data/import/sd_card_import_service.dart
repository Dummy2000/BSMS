import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../data/ble/ecg_packet_parser.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/imported_session.dart';

class SdCardImportService {
  final EcgPacketParser _parser = EcgPacketParser();

  /// Opens a file picker dialog and parses the selected binary file.
  ///
  /// Returns null if the user cancels or the file is unreadable.
  /// Throws [FormatException] if the file size is not a multiple of 47 bytes.
  Future<ImportedSession?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    return _parseBytes(
      bytes: bytes,
      fileName: file.name,
    );
  }

  ImportedSession _parseBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    const packetSize = EcgPacketParser.packetSize;
    const samplesPerPacket = EcgPacketParser.samplesPerPacket;
    const sampleIntervalMs = EcgPacketParser.sampleIntervalMs;

    if (bytes.length % packetSize != 0) {
      throw FormatException(
        'Datei "$fileName" ist beschädigt: '
        '${bytes.length} Bytes ist nicht durch $packetSize teilbar '
        '(Rest: ${bytes.length % packetSize} Bytes).',
      );
    }

    final totalBlocks = bytes.length ~/ packetSize;
    final samples = <EcgSample>[];
    int skippedBlocks = 0;
    int missingPackets = 0;
    int? lastCounter;

    final bd = ByteData.sublistView(bytes);

    for (int blockIdx = 0; blockIdx < totalBlocks; blockIdx++) {
      final offset = blockIdx * packetSize;

      // Counter from header bytes 0–3 for gap detection.
      final counter = bd.getUint32(offset, Endian.little);
      if (lastCounter != null && counter != lastCounter + 1) {
        missingPackets += (counter - lastCounter - 1).abs();
      }
      lastCounter = counter;

      final packetBytes = bytes.sublist(offset, offset + packetSize);

      try {
        // Reuse BLE parser for sample extraction (bytes 7–46).
        // Timestamps from packet.timestamp are intentionally ignored here:
        // SD-card header bytes 0–3 are a block counter, not a real timestamp.
        final packet = _parser.parse(packetBytes);

        for (int i = 0; i < packet.samples.length; i++) {
          final sampleIdx = blockIdx * samplesPerPacket + i;
          samples.add(EcgSample(
            value: packet.samples[i],
            timestampMs: sampleIdx * sampleIntervalMs,
          ));
        }
      } catch (_) {
        skippedBlocks++;
      }
    }

    return ImportedSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourceFile: fileName,
      importedAt: DateTime.now(),
      samples: samples,
      skippedPackets: skippedBlocks + missingPackets,
    );
  }
}
