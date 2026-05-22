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
    final samples = <EcgSample>[];
    int skipped = 0;

    final totalPackets = bytes.length ~/ EcgPacketParser.packetSize;

    for (int i = 0; i < totalPackets; i++) {
      final offset = i * EcgPacketParser.packetSize;
      final packetBytes = bytes.sublist(offset, offset + EcgPacketParser.packetSize);

      try {
        final packet = _parser.parse(packetBytes);
        samples.addAll(_parser.packetToSamples(packet));
      } catch (_) {
        skipped++;
      }
    }

    return ImportedSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourceFile: fileName,
      importedAt: DateTime.now(),
      samples: samples,
      skippedPackets: skipped,
    );
  }
}
