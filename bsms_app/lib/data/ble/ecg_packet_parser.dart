import 'ecg_packet.dart';

class EcgPacketParser {
  static const int packetSize = 47;

  EcgPacket parse(List<int> data) {
    if (data.length != packetSize) {
      throw ArgumentError('Invalid ECG packet size: ${data.length}');
    }

    // TODO: implement parsing logic
    throw UnimplementedError();
  }
}
