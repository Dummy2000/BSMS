import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../data/ble/ecg_packet_parser.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/imported_session.dart';

class SdCardImportService {
  /// Opens a file picker dialog and parses the selected binary file.
  ///
  /// Supports both the legacy 47-byte format (uint32 block counter in header)
  /// and the new 51-byte format (uint64 real timestamp in header).
  /// Throws [FormatException] if the file size matches neither format.
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

    return parseBytes(bytes: bytes, fileName: file.name);
  }

  /// Parses an SD card binary file already loaded into memory.
  ImportedSession parseBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    const newSize    = EcgPacketParser.packetSize;        // 51
    const legacySize = EcgPacketParser.packetSizeLegacy;  // 47
    const samplesPerPacket  = EcgPacketParser.samplesPerPacket;
    const sampleIntervalMs  = EcgPacketParser.sampleIntervalMs;

    final isNew    = bytes.length % newSize    == 0;
    final isLegacy = bytes.length % legacySize == 0;

    if (!isNew && !isLegacy) {
      throw FormatException(
        'Datei "$fileName" ist beschädigt: '
        '${bytes.length} Bytes passt weder zum neuen Format ($newSize Bytes/Block) '
        'noch zum alten Format ($legacySize Bytes/Block).',
      );
    }

    // New format: bytes 0–7 = uint64 real timestamp, samples start at byte 11.
    // Legacy format: bytes 0–3 = uint32 block counter, samples start at byte 7.
    final blockSize     = isNew ? newSize    : legacySize;
    final sampleOffset  = isNew ? 11         : 7;

    final totalBlocks    = bytes.length ~/ blockSize;
    final samples        = <EcgSample>[];
    final hrData         = <HrDataPoint>[];
    final leadOffIntervals = <LeadOffInterval>[];
    int skippedBlocks    = 0;
    int missingPackets   = 0;
    int? lastCounter;
    bool inLeadOff       = false;
    int  leadOffStart    = 0;

    final bd = ByteData.sublistView(bytes);

    for (int blockIdx = 0; blockIdx < totalBlocks; blockIdx++) {
      final offset = blockIdx * blockSize;

      // Counter / block index in first 4 bytes — used only for gap detection.
      final counter = bd.getUint32(offset, Endian.little);
      if (lastCounter != null && counter != lastCounter + 1) {
        missingPackets += (counter - lastCounter - 1).abs();
      }
      lastCounter = counter;

      // Header layout (both formats):
      //   sampleOffset - 3 = hr_avg
      //   sampleOffset - 2 = sample_count
      //   sampleOffset - 1 = status_flags
      final hrAvg      = bd.getUint8(offset + sampleOffset - 3);
      final sampleCount = bd.getUint8(offset + sampleOffset - 2);
      final flags      = bd.getUint8(offset + sampleOffset - 1);

      if (sampleCount != samplesPerPacket) {
        skippedBlocks++;
        continue;
      }

      final blockStartMs = blockIdx * samplesPerPacket * sampleIntervalMs;

      // Transmitted HR (0 = not yet calculated by firmware).
      if (hrAvg > 0) {
        hrData.add(HrDataPoint(timestampMs: blockStartMs, bpm: hrAvg));
      }

      // Lead-off detection: bits 0 (LO+) and 1 (LO-).
      final isLeadOff = (flags & 0x03) != 0;
      if (isLeadOff && !inLeadOff) {
        inLeadOff    = true;
        leadOffStart = blockStartMs;
      } else if (!isLeadOff && inLeadOff) {
        inLeadOff = false;
        leadOffIntervals.add(LeadOffInterval(startMs: leadOffStart, endMs: blockStartMs));
      }

      for (int i = 0; i < samplesPerPacket; i++) {
        // Firmware writes int16_t samples (ADS1115) — must be read signed.
        final value = bd.getInt16(offset + sampleOffset + i * 2, Endian.little);
        final sampleIdx = blockIdx * samplesPerPacket + i;
        samples.add(EcgSample(
          value: value,
          timestampMs: sampleIdx * sampleIntervalMs,
        ));
      }
    }

    // Close any lead-off interval still open at end of recording.
    if (inLeadOff) {
      leadOffIntervals.add(LeadOffInterval(startMs: leadOffStart, endMs: -1));
    }

    return ImportedSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourceFile: fileName,
      importedAt: DateTime.now(),
      samples: samples,
      skippedPackets: skippedBlocks + missingPackets,
      hrData: hrData,
      leadOffIntervals: leadOffIntervals,
    );
  }
}
