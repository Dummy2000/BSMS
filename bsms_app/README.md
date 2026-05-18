# BSMS App

This repository contains the `bsms_app` Flutter project for the biomedical ECG monitoring application.

## Project Purpose

The app is designed to connect to an ESP32-based `EKG-Holter` BLE device, parse ECG packet batches, buffer signal samples, and stream data for real-time visualization.

## Prerequisites

- Flutter SDK (tested with Flutter 3.41.9)
- Dart SDK 3.11.5 (managed by Flutter)
- Android Studio or Visual Studio Code for development
- For iOS builds: macOS with Xcode installed

## Setup

1. Open a terminal in `bsms_app`
2. Run:

```
flutter pub get
```

3. Verify static analysis:

```
flutter analyze
```

4. Run tests:

```
flutter test test/integration_test.dart
```

## Running the App

### Android

```
flutter run
```

### iOS (macOS only)

If you are building for iOS, use Xcode or Flutter on macOS.

```
flutter run
```

## Project Notes

- BLE device name: `EKG-Holter`
- BLE service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- BLE characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Packet format: 47 bytes, little-endian, 20 samples per packet
- Data rate: 500 Hz sample rate, 25 packets/s

## Linting

The project uses `flutter_lints` via `analysis_options.yaml`.
The rule `avoid_print` is disabled for now to allow debug output during development.
