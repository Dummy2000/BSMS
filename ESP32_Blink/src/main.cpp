/**
 * ESP32 ECG Holter Device Firmware
 *
 * This firmware implements a BLE GATT server that communicates with a Flutter ECG monitoring app.
 * The device receives timestamp synchronization from the app and transmits ECG data packets.
 *
 * BLE Protocol:
 * - Service UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
 * - Characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8
 *
 * Communication Flow:
 * 1. App connects via BLE
 * 2. App sends current timestamp (4 bytes, little-endian uint32_t)
 * 3. App sends start command (0x01)
 * 4. Device transmits ECG packets via notifications (47 bytes each)
 * 5. App sends stop command (0x00) to halt transmission
 *
 * ECG Packet Format (47 bytes):
 * - timestamp: uint32_t (milliseconds since app-provided base time)
 * - heartRate: uint8_t (BPM)
 * - flags: uint8_t (status flags, bit 0 = lead-off detection)
 * - samples: int16_t[20] (ECG amplitude values)
 *
 * Sampling: 500 Hz (20 samples/packet), 25 packets/second
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// BLE UUIDs (match Flutter app)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ECG Packet structure (47 bytes total) - matches Flutter app parser
struct __attribute__((packed)) EcgPacket {
    uint32_t timestamp;    // Base timestamp from app (milliseconds)
    uint8_t heartRate;     // Heart rate in BPM
    uint8_t flags;         // Status flags (bit 0: lead off)
    int16_t samples[20];   // 20 ECG samples
};

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;

// Timestamp received from app (base time for ECG packets)
uint32_t baseTimestamp = 0;

// Sample ECG data for testing (replace with actual ADC readings)
int16_t sampleData[20] = {13200, 13201, 13202, 13203, 13204, 13205, 13206, 13207, 13208, 13209,
                         13210, 13211, 13212, 13213, 13214, 13215, 13216, 13217, 13218, 13219};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected");
    }
};

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();

      if (value.length() == 4) {
        // Timestamp synchronization from app (4 bytes, little-endian)
        baseTimestamp = *(uint32_t*)value.c_str();
        Serial.printf("Timestamp received: %u ms\n", baseTimestamp);
      }
      else if (value.length() == 1) {
        // Command from app (1 byte)
        uint8_t command = value[0];
        if (command == 0x01) {
          Serial.println("Start ECG transmission command received");
          // TODO: Start ECG data transmission
        }
        else if (command == 0x00) {
          Serial.println("Stop ECG transmission command received");
          // TODO: Stop ECG data transmission
        }
      }
    }
};

void setup() {
  Serial.begin(115200);

  // Initialize BLE
  BLEDevice::init("EKG-Holter");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE ECG device ready");
}

void loop() {
  if (deviceConnected && baseTimestamp > 0) {
    // Create and send ECG packet
    EcgPacket packet;
    packet.timestamp = baseTimestamp + millis();  // Add elapsed time to base timestamp
    packet.heartRate = 72;  // Example heart rate (TODO: calculate from samples)
    packet.flags = 0x00;    // No lead-off issues (TODO: implement lead-off detection)

    // Copy sample data (TODO: replace with actual ADC readings)
    memcpy(packet.samples, sampleData, sizeof(sampleData));

    // Send packet via BLE notification
    pCharacteristic->setValue((uint8_t*)&packet, sizeof(EcgPacket));
    pCharacteristic->notify();

    Serial.printf("Sent ECG packet, timestamp: %u\n", packet.timestamp);

    // Wait for next packet (40ms = 25 packets/second = 500 samples/second)
    delay(40);

    // Update base timestamp for next packet (maintains sync with app)
    baseTimestamp += 40;
  }

  delay(10);
}