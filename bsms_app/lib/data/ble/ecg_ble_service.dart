import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ecg_packet.dart';
import 'ecg_packet_parser.dart';
import 'ble_service.dart';
import 'ble_device_connector.dart';

/// Service for handling ECG data via BLE from ESP32 device.
/// Manages the complete BLE pipeline: scan → connect → sync timestamp → start transmission → subscribe → parse.
///
/// **BLE Protocol:**
/// - Timestamp sync: App sends current time (ms since epoch) as 4-byte little-endian uint32_t
/// - Start command: 0x01 byte to begin ECG data transmission
/// - Stop command: 0x00 byte to halt ECG data transmission
/// - Data packets: 47-byte ECG packets received via notifications
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

  String? _connectedDeviceId;
  final List<int> _incomingBuffer = [];

  EcgBleService(this._parser)
      : _bleService = BleService(),
        _connector = BleDeviceConnector();

  /// Stream of parsed ECG packets from the BLE device.
  Stream<EcgPacket> get ecgPackets => _packetController.stream;

  /// Starts the BLE pipeline: scan for device, connect, synchronize timestamp,
  /// start ECG transmission, and subscribe to notifications.
  Future<void> start() async {
    if (_connectedDeviceId != null) {
      print('Already connected');
      return;
    }

    // Cancel any existing scan
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      // Start scanning for devices
      _scanSubscription = _bleService.scanForDevices().listen(
        (device) async {
          if (device.name == deviceName) {
            print('Found ECG device: ${device.name} (${device.id})');
            
            // Crucial: Stop scanning and wait a moment before connecting
            await _scanSubscription?.cancel();
            _scanSubscription = null;
            _bleService.stopScan();
            
            await Future.delayed(const Duration(milliseconds: 500));
            await _connectToDevice(device.id);
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

  /// Connects to the specified device, synchronizes timestamp with ESP32,
  /// starts ECG data transmission, and subscribes to notifications.
  Future<void> _connectToDevice(String deviceId) async {
    if (_connectedDeviceId != null) return;

    try {
      // Cancel any existing connection subscription
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      // Connect to device
      _connectionSubscription = _connector.connectTo(deviceId).listen(
        (connectionState) async {
          print('Connection state: ${connectionState.connectionState}');

          if (connectionState.connectionState == DeviceConnectionState.connected && _connectedDeviceId == null) {
            _connectedDeviceId = deviceId;

            try {
              // Request larger MTU to avoid packet fragmentation (47 bytes + headers)
              print('Requesting MTU change...');
              await _ble.requestMtu(deviceId: deviceId, mtu: 128);
              
              // Give services a moment to be discovered properly
              await Future.delayed(const Duration(seconds: 1));

              // Attempt to synchronize timestamp, but don't stop if it fails
              try {
                final currentTime = DateTime.now().millisecondsSinceEpoch;
                await sendTimestamp(deviceId, currentTime);
              } catch (e) {
                print('Optional timestamp sync failed: $e');
              }

              // Attempt to start transmission, but don't stop if it fails
              try {
                await startEcgTransmission(deviceId);
              } catch (e) {
                print('Optional start command failed: $e');
              }

              // Subscribe to notifications - THIS IS THE MOST CRITICAL PART
              await _subscribeToNotifications(deviceId);
            } catch (e) {
              print('Critical error during notification subscription: $e');
              _packetController.addError('Setup error: $e');
            }
          } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
            _connectedDeviceId = null;
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
            // Accumulate data in buffer to handle fragmented BLE packets
            _incomingBuffer.addAll(data);
            
            // Process all full packets in the buffer
            while (_incomingBuffer.length >= EcgPacketParser.packetSize) {
              final packetData = _incomingBuffer.sublist(0, EcgPacketParser.packetSize);
              _incomingBuffer.removeRange(0, EcgPacketParser.packetSize);
              
              final packet = _parser.parse(packetData);
              _packetController.add(packet);
            }
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

  /// Stops ECG transmission, cancels subscriptions, and disconnects from device.
  Future<void> stop() async {
    try {
      // Stop ECG transmission if connected
      if (_connectedDeviceId != null) {
        await stopEcgTransmission(_connectedDeviceId!);
        print('ECG transmission stopped');
      }
    } catch (e) {
      print('Error stopping ECG transmission: $e');
    }

    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _connector.disconnect();
    _bleService.stopScan();
    _connectedDeviceId = null;

    print('BLE service stopped');
  }

  /// Sends current timestamp to ESP32 for synchronization.
  /// ESP32 uses this timestamp as base for ECG packet timestamps.
  Future<void> sendTimestamp(String deviceId, int timestampMs) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(characteristicUuid),
      deviceId: deviceId,
    );

    // Send timestamp as 4-byte little-endian uint32_t
    final timestampBytes = ByteData(4);
    timestampBytes.setUint32(0, timestampMs, Endian.little);
    final data = timestampBytes.buffer.asUint8List();

    try {
      // Try writing without response first (more common for ESP32)
      await _ble.writeCharacteristicWithoutResponse(characteristic, value: data);
      print('Timestamp sent to ESP32: $timestampMs ms (no response)');
    } catch (e) {
      print('Failed to send timestamp without response: $e. Trying with response...');
      try {
        // Fallback to writing with response
        await _ble.writeCharacteristicWithResponse(characteristic, value: data);
        print('Timestamp sent to ESP32: $timestampMs ms (with response)');
      } catch (e2) {
        print('Failed to send timestamp with response fallback: $e2');
        throw Exception('Failed to send timestamp to ESP32: $e2');
      }
    }
  }

  /// Sends start command to ESP32 to begin ECG data transmission.
  Future<void> startEcgTransmission(String deviceId) async {
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuid),
        deviceId: deviceId,
      );

      // Send start command (0x01)
      await _ble.writeCharacteristicWithoutResponse(characteristic, value: [0x01]);
      print('ECG transmission start command sent to ESP32');
    } catch (e) {
      print('Failed to send start command: $e');
      throw Exception('Failed to start ECG transmission: $e');
    }
  }

  /// Sends stop command to ESP32 to halt ECG data transmission.
  Future<void> stopEcgTransmission(String deviceId) async {
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuid),
        deviceId: deviceId,
      );

      // Send stop command (0x00)
      await _ble.writeCharacteristicWithoutResponse(characteristic, value: [0x00]);
      print('ECG transmission stop command sent to ESP32');
    } catch (e) {
      print('Failed to send stop command: $e');
      throw Exception('Failed to stop ECG transmission: $e');
    }
  }

  /// Returns true if currently connected to ECG device and device ID is tracked.
  bool get isConnected => _connectedDeviceId != null;
}
