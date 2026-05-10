import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ecg_packet.dart';
import 'ecg_packet_parser.dart';
import 'ble_service.dart';
import 'ble_device_connector.dart';

/// Service for handling ECG data via BLE from ESP32 device.
/// Manages the complete BLE pipeline: scan → connect → subscribe → parse.
class EcgBleService {
  static const String deviceName = 'EKG-Holter';
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String characteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final EcgPacketParser _parser;
  final BleService _bleService;
  final BleDeviceConnector _connector;

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;

  final StreamController<EcgPacket> _packetController = StreamController<EcgPacket>.broadcast();

  EcgBleService(this._parser)
      : _bleService = BleService(),
        _connector = BleDeviceConnector();

  /// Stream of parsed ECG packets from the BLE device.
  Stream<EcgPacket> get ecgPackets => _packetController.stream;

  /// Starts the BLE pipeline: scan for device, connect, and subscribe to notifications.
  Future<void> start() async {
    try {
      // Start scanning for devices
      _scanSubscription = _bleService.scanForDevices().listen(
        (device) async {
          if (device.name == deviceName) {
            print('Found ECG device: ${device.name} (${device.id})');
            await _connectToDevice(device.id);
            _bleService.stopScan(); // Stop scanning once we found our device
          }
        },
        onError: (error) {
          print('Scan error: $error');
          _packetController.addError(error);
        },
      );
    } catch (e) {
      print('Failed to start BLE service: $e');
      _packetController.addError(e);
    }
  }

  /// Connects to the specified device and subscribes to ECG notifications.
  Future<void> _connectToDevice(String deviceId) async {
    try {
      // Connect to device
      _connectionSubscription = _connector.connectTo(deviceId).listen(
        (connectionState) async {
          print('Connection state: ${connectionState.connectionState}');

          if (connectionState.connectionState == DeviceConnectionState.connected) {
            await _subscribeToNotifications(deviceId);
          } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
            print('Device disconnected');
            _packetController.addError('Device disconnected');
          }
        },
        onError: (error) {
          print('Connection error: $error');
          _packetController.addError(error);
        },
      );
    } catch (e) {
      print('Failed to connect to device: $e');
      _packetController.addError(e);
    }
  }

  /// Subscribes to ECG data notifications from the characteristic.
  Future<void> _subscribeToNotifications(String deviceId) async {
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuid),
        deviceId: deviceId,
      );

      _notificationSubscription = _ble.subscribeToCharacteristic(characteristic).listen(
        (data) {
          try {
            // Parse raw bytes into ECG packet
            final packet = _parser.parse(data);
            _packetController.add(packet);
          } catch (e) {
            print('Failed to parse ECG packet: $e');
            _packetController.addError('Parse error: $e');
          }
        },
        onError: (error) {
          print('Notification error: $error');
          _packetController.addError(error);
        },
      );

      print('Subscribed to ECG notifications');
    } catch (e) {
      print('Failed to subscribe to notifications: $e');
      _packetController.addError(e);
    }
  }

  /// Stops the BLE pipeline and disconnects from device.
  void stop() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _connector.disconnect();
    _bleService.stopScan();
    _packetController.close();

    print('BLE service stopped');
  }

  /// Returns true if currently connected to ECG device.
  bool get isConnected => _connectionSubscription != null;
}
