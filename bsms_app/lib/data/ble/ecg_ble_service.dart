class EcgBleService {
  final EcgPacketParser parser;

  EcgBleService(this.parser);

  Stream<EcgPacket> get ecgPackets {
    // TODO: scan
    // TODO: connect
    // TODO: subscribe to notifications
    // TODO: forward raw packets to parser
    throw UnimplementedError();
  }
}
