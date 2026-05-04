import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Handles connecting and disconnecting from a BLE device.
/// Uses stream subscriptions because flutter_reactive_ble no longer
/// provides a direct disconnectDevice() method.
class BleDeviceConnector {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  /// Connects to a BLE device and returns a stream of connection updates.
  Stream<ConnectionStateUpdate> connectTo(String deviceId) {
    // Cancel previous connection if any
    _connectionSubscription?.cancel();

    final connectionStream = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 5),
    );

    // Store subscription so we can cancel it later
    _connectionSubscription = connectionStream.listen((event) {
      // You can add logging here if needed
    });

    return connectionStream;
  }

  /// Disconnects by cancelling the connection subscription.
  void disconnect() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }
}
