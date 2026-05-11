# 🚀 Quick Start - Bluetooth Connection Testing

## ⚡ 30-Second Connection Guide

### Prerequisites
- [ ] ESP32 powered on with name "EKG-Holter"
- [ ] Android device/emulator with Bluetooth enabled
- [ ] APK deployed (or `flutter run --debug`)

### Connection Steps
```
1. Launch app
2. Grant permissions (Android will ask)
3. Click "Start BLE"
4. Watch status change to "Connected - Receiving data"
5. Packet counter starts incrementing (~25 packets/sec)
6. Click "Stop BLE" when done
```

**That's it!** The app handles all BLE communication automatically.

---

## 🔍 What to Look For

✅ **Success Indicators:**
- Status: `Connected - Receiving data`
- Packets: Counter increasing (25+ per second)
- Last packet shows real data:
  - Timestamp: Non-zero milliseconds
  - Heart rate: 72 BPM
  - Flags: 0x00
  - Samples: 20

---

## ❌ If Connection Fails

| Issue | Fix |
|-------|-----|
| "Not connected" | Check ESP32 is on, in range, named "EKG-Holter" |
| "Permission denied" | Android: Grant location permission |
| "Packets: 0" | Restart ESP32, check serial logs |
| No status update | App crashed - check logs with `flutter logs` |

---

## 📱 App Workflow

```
Start BLE
   ↓
Scanning for "EKG-Holter"
   ↓
Device found & connected
   ↓
Send timestamp to ESP32
   ↓
Send start command (0x01)
   ↓
Receive ECG packets (47 bytes each)
   ↓
Parse & display in real-time
   ↓
Stop BLE (send 0x00, disconnect)
```

---

## 📊 Expected Metrics

- **Connection time**: ~1-3 seconds
- **Packet rate**: 25 packets/second
- **Samples/packet**: 20
- **Sampling rate**: 500 Hz
- **Data format**: 47-byte packets (little-endian)

---

## 🔧 BLE Protocol (Reference)

```
App → ESP32:
  Timestamp (4 bytes, ms since epoch)
  Start (0x01) or Stop (0x00)

ESP32 → App:
  ECG packets (47 bytes, continuous)
    - 4-byte timestamp
    - 1-byte heart rate (BPM)
    - 1-byte flags (status)
    - 40-byte samples (20 × uint16)
```

---

## 📚 For Detailed Info

See: `BLE_TESTING_GUIDE.md` or `BLUETOOTH_CONNECTION_STATUS.md`

---

**Ready to test?** Deploy the app and connect! 🎯
