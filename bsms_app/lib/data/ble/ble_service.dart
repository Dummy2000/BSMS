import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Handles BLE scanning for nearby devices.
/// This class only discovers devices — it does not connect to them.
class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  /// Starts scanning for BLE devices.
  /// We do not filter by service UUID because the ESP32 advertises without it.
  Stream<DiscoveredDevice> scanForDevices() {
    return _ble.scanForDevices(
      withServices: [], // No filter → discover all devices
      scanMode: ScanMode.lowLatency,
    );
  }

  /// Stops scanning.
  void stopScan() {
    _ble.deinitialize(); // Safely stops scanning
  }
}
