# ESP32 ECG Holter Device

ESP32-based Bluetooth ECG monitoring device that collects ECG data and transmits it to a Flutter mobile application.

## Hardware Requirements

- ESP32 development board (ESP32-WROOM-32 recommended)
- ECG sensor/electrodes (ADS1292 or similar)
- Power supply (3.3V-5V)

## BLE Protocol

The device implements a BLE GATT server with the following characteristics:

- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristic UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

### Communication Protocol

1. **Timestamp Synchronization**: App sends current timestamp (4 bytes, little-endian uint32_t)
2. **Start Command**: App sends 0x01 to begin ECG data transmission
3. **Stop Command**: App sends 0x00 to halt ECG data transmission
4. **Data Transmission**: Device sends 47-byte ECG packets via BLE notifications

### ECG Packet Format (47 bytes)

```c
struct __attribute__((packed)) EcgPacket {
    uint32_t timestamp;    // Base timestamp + elapsed time (milliseconds)
    uint8_t heartRate;     // Heart rate in BPM
    uint8_t flags;         // Status flags (bit 0: lead off detection)
    int16_t samples[20];   // 20 ECG samples (2ms intervals)
};
```

- **Sampling Rate**: 500 Hz (20 samples per packet)
- **Packet Rate**: 25 packets/second (40ms intervals)
- **Data Format**: Little-endian

## Setup Instructions

1. Install PlatformIO IDE or VS Code with PlatformIO extension
2. Open the project folder in PlatformIO
3. Connect ESP32 board via USB
4. Build and upload the firmware:
   ```bash
   pio run -t upload
   ```

## Dependencies

- Arduino framework
- ESP32 BLE library

## Testing

The current implementation includes sample ECG data for testing. Replace the `sampleData` array in `main.cpp` with actual ADC readings from your ECG sensor.

## Integration with Flutter App

The device is designed to work with the BSMS Flutter application. Ensure the BLE UUIDs match between the ESP32 firmware and Flutter app configuration.