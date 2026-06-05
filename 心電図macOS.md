# BSMS ECG Monitor — Developer Setup Guide

**Biomedical Signal Monitoring System**
A cross-platform Flutter app that connects to an ESP32 over BLE and displays real-time ECG waveforms.

---

## What This App Does

| Feature | Details |
|---|---|
| Real-time ECG display | Live waveform from ESP32 at 500 Hz |
| Signal modes | Raw / Filtered (IIR bandpass) / R-Peak overlay |
| Heart rate | BPM calculated from R-R intervals |
| Event detection | Tachycardia (>100 BPM), Bradycardia (<50 BPM), Arrhythmia |
| BLE scan | Auto-detects ESP32 by device name |
| CSV export | Save recording and share via AirDrop / email |
| Demo mode | Works without hardware — simulated ECG waveform |
| Languages | English / Japanese / German (switchable in Settings) |
| Platforms | iOS · Android · macOS |

---

## Repository Layout

```
BSMS-main-2/
├── bsms_app/                    ← Flutter app (this guide focuses here)
│   ├── lib/
│   │   ├── app/                 ← App entry, settings, routing
│   │   ├── data/
│   │   │   ├── ble/             ← BLE scanner, packet parser, demo generator
│   │   │   ├── buffer/          ← Ring buffer (2000-sample circular FIFO)
│   │   │   └── storage/         ← CSV save, session history
│   │   ├── domain/
│   │   │   └── processing/      ← EcgFilter, RPeakDetector, EventDetectionService
│   │   ├── l10n/                ← Localization (EN / JA / DE)
│   │   └── presentation/
│   │       ├── live_ecg/        ← Main ECG screen + ViewModel
│   │       ├── ble_scan/        ← BLE device scanner screen
│   │       ├── history/         ← Session list & detail
│   │       └── settings/        ← App settings screen
│   ├── test/                    ← 69 unit + integration tests
│   ├── android/                 ← Android BLE permissions
│   ├── ios/                     ← iOS BLE permissions + Info.plist
│   └── macos/                   ← macOS BLE permissions + Entitlements
├── Integrated ESP32 Firmware    ← ESP32 source code
├── ESP32_Blink/                 ← PlatformIO project
└── Offline ECG Filter Script (Python)
```

---

## Requirements

| Tool | Minimum version | Where to get |
|---|---|---|
| Flutter SDK | 3.32 or later | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.11.5 (bundled with Flutter) | — |
| Xcode | 15 or later (macOS / iOS only) | Mac App Store |
| CocoaPods | 1.16 or later | `sudo gem install cocoapods` |
| Android Studio | Ladybug or later (Android only) | https://developer.android.com/studio |
| VS Code (optional) | Any | With Flutter extension |

Check your Flutter setup with:

```bash
flutter doctor
```

All items should show a green checkmark before proceeding.

---

## Cloning the Repository

```bash
git clone https://github.com/kamesky1202-debug/ECG-Mobile-Project.git
cd ECG-Mobile-Project/bsms_app
```

---

## First-Time Setup

```bash
# Inside bsms_app/

# 1. Download all Dart packages
flutter pub get

# 2. Regenerate localization files (English / Japanese / German)
flutter gen-l10n

# 3. Verify everything compiles with zero warnings
flutter analyze
```

Expected output of `flutter analyze`:
```
No issues found!
```

---

## Running the App

### macOS (recommended for development)

```bash
flutter run -d macos
```

> No physical ECG hardware needed — tap **Start Demo** in the app to see a simulated waveform.

### iOS (requires iPhone connected via USB)

```bash
flutter run -d <your-device-id>
```

First time on a physical iPhone:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to **Signing & Capabilities** → set your Apple ID team
3. Change **Bundle Identifier** to something unique (e.g. `com.yourname.bsmsEcg`)
4. Trust the developer certificate on your iPhone: **Settings → General → VPN & Device Management**

### Android (requires Android phone connected via USB or emulator)

```bash
flutter run -d <your-device-id>
```

Enable Developer Mode on the phone: **Settings → About Phone → tap Build Number 7 times**

---

## macOS — Bluetooth Permission Setup (Already Done)

macOS requires two levels of Bluetooth permission. Both are already configured in this repo — no changes needed unless you modify the Bundle ID.

### Level 1 — Info.plist (usage description shown to the user)

**File:** `macos/Runner/Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to connect to ECG monitoring devices.</string>
```

### Level 2 — Entitlements (App Sandbox permission)

**File:** `macos/Runner/DebugProfile.entitlements`  (used when running via `flutter run`)

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

**File:** `macos/Runner/Release.entitlements`  (used when running `flutter build macos`)

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

> **Why both files?** macOS sandboxes every app by default. `Info.plist` provides the human-readable reason shown in the system dialog; the Entitlements files grant the actual OS-level permission. Missing either one will cause BLE scanning to silently fail.

---

## iOS — Bluetooth Permission Setup (Already Done)

**File:** `ios/Runner/Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to connect to ECG monitoring devices.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to connect to ECG monitoring devices.</string>
```

---

## Android — Bluetooth Permission Setup (Already Done)

**File:** `android/app/src/main/AndroidManifest.xml`

Permissions already declared:
- `BLUETOOTH_SCAN` (Android 12+, `neverForLocation`)
- `BLUETOOTH_CONNECT` (Android 12+)
- `BLUETOOTH` / `BLUETOOTH_ADMIN` (Android 11 and below)
- `ACCESS_FINE_LOCATION` (required for BLE on Android ≤ 11)

---

## Key Packages

| Package | Purpose |
|---|---|
| `flutter_reactive_ble ^5.5.0` | BLE scanning and GATT characteristic subscription |
| `syncfusion_flutter_charts ^33.2.6` | Real-time ECG waveform chart (FastLineSeries) |
| `shared_preferences ^2.3.0` | Persist settings (device name, thresholds, language) |
| `path_provider ^2.0.15` | Get platform-correct Documents directory for CSV files |
| `share_plus ^10.1.4` | Native Share Sheet (AirDrop, email, etc.) |
| `flutter_localizations` | Built-in Flutter i18n support |

---

## Signal Processing Architecture

```
ESP32 (BLE)
    │  47-byte packet every 40 ms
    │  [Uint32 timestamp | Uint32 heart_rate | 20 × Uint16 ADC samples]
    ▼
EcgPacketParser          → decodes binary packet → List<EcgSample>
    ▼
EcgRingBuffer            → circular FIFO, capacity 2000 samples
    ▼
EcgFilter                → IIR bandpass 0.5–40 Hz @ 500 Hz sample rate
    ▼
RPeakDetector            → Pan-Tompkins algorithm → R-peak flags + BPM
    ▼
EventDetectionService    → tachycardia / bradycardia / arrhythmia alerts
    ▼
LiveEcgViewModel         → exposes chartSamples + peakIndices to UI
    ▼
LiveEcgScreen            → FastLineSeries chart + ScatterSeries R-peak markers
```

### Signal Display Modes

Switch modes using the segmented control at the top of the ECG screen:

| Mode | What is shown |
|---|---|
| **Raw** | Direct ADC values from ESP32 (0–4095) |
| **Filtered** | After IIR bandpass filter — cleaner baseline |
| **R-Peaks** | Filtered signal + red inverted-triangle markers at each R-peak |

---

## BLE Packet Format

The ESP32 firmware sends one packet every 40 ms (500 Hz effective sampling rate):

```
Offset  Size   Type      Field
──────  ────   ────────  ──────────────────────────────────
0       4      Uint32    Device uptime in milliseconds
4       4      Uint32    Heart rate from ESP32 hardware
8–46    20×2   Uint16[]  20 ADC samples (little-endian, 0–4095)
```

Total: **47 bytes per packet**, 20 samples × 25 packets/s = **500 samples/s**

> The timestamp is device uptime (e.g. 5000 = 5 seconds since boot), **not** a Unix timestamp. The app ring buffer handles this correctly.

---

## ESP32 Connection Flow

1. Tap **BLE Connect** on the ECG screen
2. The BLE scan screen opens and searches for nearby devices
3. Devices whose name contains `"ECG"` or `"Holter"` are highlighted automatically
4. Tap the ESP32 device to connect
5. The app subscribes to the GATT notification characteristic and starts receiving data
6. Tap **Disconnect** to end the session

**Default device name filter:** `"ECG"` (configurable in Settings)

---

## Settings

All settings are saved automatically via `SharedPreferences`.

| Setting | Default | Description |
|---|---|---|
| Device name | `"ECG"` | Partial match filter for BLE scan |
| Tachycardia threshold | 100 BPM | Alert shown above this value |
| Bradycardia threshold | 50 BPM | Alert shown below this value |
| Arrhythmia threshold | 50 ms | RR standard deviation limit |
| Language | System | English / Japanese / German |

---

## Running Tests

```bash
cd bsms_app

# Run all tests (69 total)
flutter test

# Run a specific test file
flutter test test/domain/ecg_filter_test.dart
```

Test coverage:

| File | What is tested |
|---|---|
| `test/domain/ecg_filter_test.dart` | IIR bandpass filter output |
| `test/domain/r_peak_detector_test.dart` | Pan-Tompkins R-peak detection |
| `test/domain/event_detection_test.dart` | Tachycardia / bradycardia / arrhythmia logic |
| `test/data/ecg_packet_parser_test.dart` | 47-byte BLE packet decoding |
| `test/data/ecg_ring_buffer_test.dart` | Ring buffer overflow, peek operations |
| `test/data/ecg_demo_test.dart` | Demo waveform generator |
| `test/integration_test.dart` | Full pipeline: packet → buffer → filter → peak |
| `test/widget_test.dart` | App launch smoke test |

---

## Building a Release Binary

### macOS

```bash
flutter build macos
# Output: bsms_app/build/macos/Build/Products/Release/bsms_app.app
```

### iOS (requires paid Apple Developer account for distribution)

```bash
flutter build ios --release
```

Then archive and distribute from Xcode.

### Android APK

```bash
flutter build apk --release
# Output: bsms_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

### BLE scanning does nothing on macOS
- Check **System Settings → Privacy & Security → Bluetooth** — allow the app
- Verify both Entitlements files contain `com.apple.security.device.bluetooth = true`
- Rebuild after any plist change: `flutter clean && flutter run -d macos`

### BLE scanning does nothing on iOS
- Physical device required — BLE does not work in the simulator
- Make sure both `NSBluetoothAlwaysUsageDescription` keys are in `ios/Runner/Info.plist`

### `flutter gen-l10n` missing strings error
```bash
flutter gen-l10n
flutter analyze
```

### CocoaPods errors on macOS / iOS
```bash
cd macos   # or ios
pod install
cd ..
flutter run -d macos
```

### `flutter doctor` reports Xcode issues
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

---

## Project Authors

Developed as a university biomedical engineering project.
Hardware: ESP32 + ECG analog front-end
Software: Flutter (Dart), signal processing in pure Dart

GitHub: https://github.com/kamesky1202-debug/ECG-Mobile-Project
