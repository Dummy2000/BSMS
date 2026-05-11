# BLE Connection Testing Guide

## ✅ Application Readiness

Your Flutter application is now ready for Bluetooth LE connection testing. Here's what has been implemented:

### What's Ready

1. **BLE Service** (`EcgBleService`)
   - ✅ Device scanning (searches for "EKG-Holter")
   - ✅ Automatic connection establishment
   - ✅ Timestamp synchronization with ESP32
   - ✅ Start/Stop command transmission
   - ✅ Packet reception and parsing

2. **Permissions**
   - ✅ Android manifest updated with BLE permissions
   - ✅ iOS Info.plist updated with Bluetooth usage descriptions
   - ✅ Location permissions included (required for BLE scanning on Android 6+)

3. **Test Interface** (temporary in `app.dart`)
   - ✅ Connection status display
   - ✅ Packet counter and data preview
   - ✅ Start/Stop BLE buttons
   - ✅ Real-time packet statistics

## 🔌 How to Connect

### Step 1: Prepare ESP32 Device
```
1. Ensure ESP32 firmware is uploaded with BLE support
2. Power on the ESP32 with "EKG-Holter" name
3. Verify device is in Bluetooth range
```

### Step 2: Launch Application
```
Windows/macOS:
  flutter run --debug

Android:
  flutter run --debug -d <device_id>
  
iOS:
  flutter run --debug -d <device_id>
```

### Step 3: Grant Permissions (Android)
- App will request Bluetooth and Location permissions
- Click "Allow" to proceed with scanning

### Step 4: Test Connection
```
1. In the app, click "Start BLE"
2. App will scan for "EKG-Holter"
3. Upon connection:
   - App sends current timestamp to ESP32
   - App sends start command (0x01)
   - ESP32 begins transmitting ECG packets
4. Monitor status and packet count
```

### Step 5: Stop Connection
```
1. Click "Stop BLE" to disconnect
2. App sends stop command (0x00) to ESP32
3. Subscriptions are cancelled
```

## 📱 Platform-Specific Notes

### Android
- **Target API**: 33+
- **Permissions**: BLUETOOTH, BLUETOOTH_ADMIN (legacy), BLUETOOTH_SCAN, BLUETOOTH_CONNECT
- **Location**: FINE_LOCATION (required for BLE scanning)
- **Runtime**: Request Bluetooth permissions at runtime on Android 12+

### iOS
- **Requirements**: iOS 11.1+
- **Permissions**: NSBluetoothAlwaysUsageDescription, NSBluetoothPeripheralUsageDescription
- **No location permission needed** (different from Android)

### Windows/macOS
- **Limitations**: Limited BLE support, mainly for testing UI
- **Note**: Actual BLE hardware testing should use Android/iOS devices

## 🔍 Connection Flow

```
App → ESP32 Communication:
1. [App] Scan for "EKG-Holter"
2. [App] Connect to device
3. [App] Send timestamp (4 bytes)
   └─> Format: little-endian uint32_t ms since epoch
4. [App] Send start command (0x01)
   └─> Device begins ECG transmission
5. [App] Subscribe to notifications
6. [ESP32] Send ECG packets (47 bytes each)
   └─> 25 packets/second = 500 samples/second
7. [App] Parse packets and display data
8. [App] Send stop command (0x00)
   └─> Device stops transmission
```

## 📊 Expected Output

When connected successfully:
- Status: "Connected - Receiving data"
- Packet counter: Incrementing (25 packets/second)
- Last packet display:
  - Timestamp (ms)
  - Heart rate (BPM)
  - Flags (0x00 = normal)
  - Sample count (20)

## ❌ Troubleshooting

### "Not connected" after clicking Start
- Check ESP32 is powered and in range
- Verify device name is "EKG-Holter"
- Check device Bluetooth is enabled
- On Android: Grant location permission

### "Error: Connection failed"
- ESP32 may have crashed or lost power
- Try rebooting ESP32 and app
- Check BLE UUID matches in code:
  - Service: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
  - Characteristic: beb5483e-36e1-4688-b7f5-ea07361b26a8

### "Packets received: 0"
- ESP32 may not be responding to start command
- Verify ESP32 received timestamp (check serial logs)
- Try manual restart of ESP32

### "Permission denied"
- Android: Check manifest has all required permissions
- iOS: Check Info.plist has usage descriptions
- User may have denied permissions in settings

## 🧪 Testing Checklist

- [ ] App launches without errors
- [ ] BLE button responds to clicks
- [ ] Permission request appears (Android)
- [ ] Status changes to "Scanning for ECG device..."
- [ ] ESP32 device appears in scan
- [ ] Connection establishes
- [ ] Timestamp sent successfully
- [ ] Start command sent
- [ ] Packets begin arriving
- [ ] Packet counter increments
- [ ] Stop button works
- [ ] Disconnection clean

## 📝 Next Steps

After successful BLE connection testing:
1. Implement actual UI screens for live ECG display
2. Add data storage/recording functionality
3. Implement signal processing (filtering, HR calculation)
4. Add device management screen for multiple devices
5. Implement session history tracking

## 🔗 References

- [flutter_reactive_ble documentation](https://pub.dev/packages/flutter_reactive_ble)
- [Android BLE best practices](https://developer.android.com/guide/topics/connectivity/bluetooth-le)
- [iOS CoreBluetooth guide](https://developer.apple.com/documentation/corebluetooth)
