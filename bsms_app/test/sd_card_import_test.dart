import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bsms_app/data/import/sd_card_import_service.dart';

/// Known int16 sample values, including negatives and both int16 extremes.
const _samples = <int>[
  -11068, 26300, -1, -32768, 32767, 0, -500, 1200, -2048, 4095,
  -11068, 26300, -1, -32768, 32767, 0, -500, 1200, -2048, 4095,
];

/// Builds one packet: timestamp | hr_avg | sample_count | status_flags | int16[20].
/// [timestampBytes] = 8 for the current format (51 B), 4 for legacy (47 B).
Uint8List _buildPacket({required int timestampBytes}) {
  final size = timestampBytes + 3 + _samples.length * 2;
  final bd = ByteData(size);
  if (timestampBytes == 8) {
    bd.setUint64(0, 1759579200000, Endian.little);
  } else {
    bd.setUint32(0, 123456, Endian.little);
  }
  bd.setUint8(timestampBytes, 72);                 // hr_avg
  bd.setUint8(timestampBytes + 1, _samples.length); // sample_count
  bd.setUint8(timestampBytes + 2, 0);              // status_flags
  for (int i = 0; i < _samples.length; i++) {
    bd.setInt16(timestampBytes + 3 + i * 2, _samples[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

void main() {
  final service = SdCardImportService();

  test('51-byte packet: negative int16 samples are read as negative', () {
    final bytes = _buildPacket(timestampBytes: 8);
    expect(bytes.length, 51);

    final session = service.parseBytes(bytes: bytes, fileName: 'test.bin');
    final values = session.samples.map((s) => s.value).toList();

    expect(values, _samples);
    expect(values[0], -11068);
    expect(values[3], -32768);
    expect(values.every((v) => v >= -32768 && v <= 32767), isTrue);
  });

  test('47-byte legacy packet: negative int16 samples are read as negative', () {
    final bytes = _buildPacket(timestampBytes: 4);
    expect(bytes.length, 47);

    final session = service.parseBytes(bytes: bytes, fileName: 'legacy.bin');

    expect(session.samples.map((s) => s.value).toList(), _samples);
  });
}
