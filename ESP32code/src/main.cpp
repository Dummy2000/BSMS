#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <SPI.h>
#include <SD.h>

volatile uint8_t currentHR = 0;

// ===== UUIDs =====
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ===== Pins =====
constexpr uint8_t LO_PLUS_PIN  = 35;
constexpr uint8_t LO_MINUS_PIN = 36;
constexpr uint8_t SD_CS_PIN    = 5;   // SPI Chip Select für SD

// LED-Pin. Active-high (HIGH = an, LOW = aus).
// GPIO21 (XIAO built-in) ist active-low — dort HIGH/LOW tauschen.
constexpr uint8_t LED_PIN = 2;

// ===== Timezone =====
// Vienna: UTC+1 (CET, winter) or UTC+2 (CEST, summer — currently active)
constexpr int UTC_OFFSET_HOURS = 2;

// ===== Sampling =====
constexpr float SAMPLE_RATE_HZ        = 500.0f;
unsigned long   nextSampleTime;
constexpr unsigned long REFRACTORY_MS = 200;

// ===== ADS1115 =====
Adafruit_ADS1115 ads;
int16_t baseline = 13200;

// ===== BLE Globals =====
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

// ===== Zeit-Synchronisation =====
// Die App schickt beim Verbinden die aktuelle Uhrzeit (Unix-ms, 8 Byte LE).
// Damit werden boot-relative millis() in echte Timestamps umgerechnet.
static volatile uint64_t g_syncWallMs = 0;  // Uhrzeit vom App-Paket (Unix ms)
static volatile uint32_t g_syncBootMs = 0;  // millis() zum Sync-Zeitpunkt
static volatile bool     g_timeSynced = false;

inline uint64_t realTimestampMs(unsigned long now_ms) {
  if (!g_timeSynced) return (uint64_t)now_ms;
  return g_syncWallMs + (uint64_t)(now_ms - g_syncBootMs);
}

// ===== SD-Karte =====
File ekgFile;
bool sdAvailable = false;
constexpr unsigned long FLUSH_INTERVAL_MS = 5000;
unsigned long lastFlushMs = 0;

// ===== Batch-Konfiguration =====
constexpr uint8_t SAMPLES_PER_BATCH = 20;

struct __attribute__((packed)) EcgPacket {
  uint64_t timestamp_ms;   // Unix-Epoch ms (uint64) — Paketgröße = 51 Bytes
  uint8_t  hr_avg;
  uint8_t  sample_count;
  uint8_t  status_flags;
  int16_t  samples[SAMPLES_PER_BATCH];
};

constexpr uint8_t STATUS_LO_PLUS  = 0x01;
constexpr uint8_t STATUS_LO_MINUS = 0x02;

EcgPacket currentPacket;
uint8_t   batchIndex = 0;

struct EcgSample {
  uint64_t timestamp_ms;
  int16_t  adc_value;
  uint8_t  hr_avg;
  uint8_t  status;
};


// (NEU) LED setzen - kapselt die active-low-Logik
void setLed(bool on) {
  digitalWrite(LED_PIN, on ? HIGH : LOW);
}


// ============================================================================
//  PAN-TOMPKINS PIPELINE
// ============================================================================

struct Biquad {
  float b0, b1, b2;
  float a1, a2;
  float x1, x2;
  float y1, y2;

  float process(float x) {
    float y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x;
    y2 = y1; y1 = y;
    return y;
  }
};

Biquad bandpass = {
  0.0305f, 0.0f, -0.0305f, -1.9347f, 0.9389f, 0, 0, 0, 0
};

float diffBuf[5] = {0};

float differentiate(float x) {
  diffBuf[4] = diffBuf[3];
  diffBuf[3] = diffBuf[2];
  diffBuf[2] = diffBuf[1];
  diffBuf[1] = diffBuf[0];
  diffBuf[0] = x;
  return 0.125f * (-diffBuf[4] - 2.0f * diffBuf[3] + 2.0f * diffBuf[1] + diffBuf[0]);
}

inline float square(float x) { return x * x; }

constexpr uint8_t MWI_WINDOW = 75;
float    mwiBuf[MWI_WINDOW] = {0};
uint8_t  mwiIdx = 0;
float    mwiSum = 0;

float integrate(float x) {
  mwiSum -= mwiBuf[mwiIdx];
  mwiBuf[mwiIdx] = x;
  mwiSum += x;
  mwiIdx = (mwiIdx + 1) % MWI_WINDOW;
  return mwiSum / MWI_WINDOW;
}

float SPKI = 0;
float NPKI = 0;
unsigned long lastPeakTime = 0;
unsigned long lastBeatTimeForRR = 0;
float hrSmoothed = 0;
float    candidatePeak = 0;
unsigned long candidateTime = 0;
bool     trackingPeak = false;

void detectPeakPT(float mwiValue, unsigned long now_ms) {
  static unsigned long initStartTime = 0;
  static float initMaxMwi = 0;
  static float initSumMwi = 0;
  static uint32_t initCount = 0;
  static bool initialized = false;

  if (!initialized) {
    if (initStartTime == 0) initStartTime = now_ms;
    if (mwiValue > initMaxMwi) initMaxMwi = mwiValue;
    initSumMwi += mwiValue;
    initCount++;
    if (now_ms - initStartTime >= 2000) {
      float meanMwi = initSumMwi / initCount;
      SPKI = initMaxMwi / 3.0f;
      NPKI = meanMwi / 2.0f;
      initialized = true;
      Serial.printf("PT init: SPKI=%.0f NPKI=%.0f\n", SPKI, NPKI);
    }
    return;
  }

  float threshold = NPKI + 0.25f * (SPKI - NPKI);

  if (mwiValue > threshold) {
    if (!trackingPeak || mwiValue > candidatePeak) {
      candidatePeak = mwiValue;
      candidateTime = now_ms;
    }
    trackingPeak = true;
  } else {
    if (trackingPeak) {
      bool refractoryOk = (candidateTime - lastPeakTime > REFRACTORY_MS);
      if (refractoryOk) {
        SPKI = 0.125f * candidatePeak + 0.875f * SPKI;
        if (lastBeatTimeForRR > 0) {
          unsigned long rr = candidateTime - lastBeatTimeForRR;
          uint16_t hrInstant = 60000 / rr;
          if (hrInstant >= 30 && hrInstant <= 220) {
            if (hrSmoothed == 0) {
              hrSmoothed = hrInstant;
            } else if (abs((int)hrInstant - (int)hrSmoothed) <= 30) {
              hrSmoothed = 0.2f * hrInstant + 0.8f * hrSmoothed;
            }
            currentHR = (uint8_t)hrSmoothed;
          }
        }
        lastBeatTimeForRR = candidateTime;
        lastPeakTime = candidateTime;
      } else {
        NPKI = 0.125f * candidatePeak + 0.875f * NPKI;
      }
      trackingPeak = false;
      candidatePeak = 0;
    }
  }
}


// ============================================================================
//  Serial / BLE
// ============================================================================

void printSample(const EcgSample& s) {
  uint32_t hours, minutes, seconds, ms_part;
  if (g_timeSynced) {
    // Real wall-clock time: apply Vienna offset and extract time-of-day
    uint64_t dayMs = (s.timestamp_ms + (uint64_t)UTC_OFFSET_HOURS * 3600000ULL) % 86400000ULL;
    hours   = (uint32_t)(dayMs / 3600000ULL);
    minutes = (uint32_t)((dayMs % 3600000ULL) / 60000ULL);
    seconds = (uint32_t)((dayMs % 60000ULL)   / 1000ULL);
    ms_part = (uint32_t)(dayMs % 1000ULL);
  } else {
    // No sync yet: show elapsed time since boot
    uint64_t t = s.timestamp_ms;
    hours   = (uint32_t)(t / 3600000ULL);
    minutes = (uint32_t)((t % 3600000ULL) / 60000ULL);
    seconds = (uint32_t)((t % 60000ULL)   / 1000ULL);
    ms_part = (uint32_t)(t % 1000ULL);
  }

  const char* statusStr = "OK";
  if (s.status & STATUS_LO_PLUS && s.status & STATUS_LO_MINUS) statusStr = "BOTH-OFF";
  else if (s.status & STATUS_LO_PLUS)                          statusStr = "LO+OFF";
  else if (s.status & STATUS_LO_MINUS)                         statusStr = "LO-OFF";

  Serial.printf("%02u:%02u:%02u.%03u,%d,%03u,%s\n",
                hours, minutes, seconds, ms_part, s.adc_value, s.hr_avg, statusStr);
}

// Empfängt Schreibzugriffe der Flutter-App:
//   8 Bytes  → Unix-Uhrzeit in ms (little-endian uint64) → Zeit-Sync
//   1 Byte 0x01 → Start-Befehl (reserviert)
//   1 Byte 0x00 → Stop-Befehl  (reserviert)
class MyCharCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    std::string value = pChar->getValue();
    size_t      len   = value.length();
    const uint8_t* data = (const uint8_t*)value.data();

    if (len == 8) {
      uint64_t wallMs = 0;
      memcpy(&wallMs, data, 8);
      g_syncWallMs = wallMs;
      g_syncBootMs = (uint32_t)millis();
      g_timeSynced = true;
      Serial.printf("Zeit synchronisiert: %llu ms (Unix-Epoch)\n", wallMs);
    } else if (len == 1) {
      Serial.printf("Befehl empfangen: 0x%02X\n", data[0]);
    }
  }
};

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    setLed(true);
    Serial.println("Client connected");
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    setLed(false);
    Serial.println("Client disconnected");
    BLEDevice::startAdvertising();
  }
};


// ============================================================================
//  SD-KARTEN-SETUP
// ============================================================================

String findNextFilename() {
  for (int i = 1; i < 1000; i++) {
    char buf[20];
    snprintf(buf, sizeof(buf), "/EKG_%03d.bin", i);
    if (!SD.exists(buf)) {
      return String(buf);
    }
  }
  return String("/EKG_999.bin");
}

void setupSD() {
  Serial.println("Initialisiere SD-Karte...");
  if (!SD.begin(SD_CS_PIN)) {
    Serial.println("FEHLER: SD-Karte nicht gefunden!");
    sdAvailable = false;
    return;
  }

  uint8_t cardType = SD.cardType();
  if (cardType == CARD_NONE) {
    Serial.println("FEHLER: Keine SD-Karte erkannt!");
    sdAvailable = false;
    return;
  }

  Serial.printf("Card Size: %llu MB\n", SD.cardSize() / (1024 * 1024));

  String filename = findNextFilename();
  Serial.printf("Schreibe nach: %s\n", filename.c_str());

  ekgFile = SD.open(filename, FILE_WRITE);
  if (!ekgFile) {
    Serial.println("FEHLER: Datei konnte nicht angelegt werden!");
    sdAvailable = false;
    return;
  }

  sdAvailable = true;
  Serial.println("SD-Karte bereit.");
}


// ============================================================================
//  SETUP
// ============================================================================

void setup() {
  Serial.begin(921600);
  delay(500);
  Serial.println("Start (ADS1115 + Pan-Tompkins + SD)...");

  // (NEU) LED-Pin konfigurieren, initial AUS
  pinMode(LED_PIN, OUTPUT);
  setLed(false);

  // ----- I²C + ADS1115 -----
  Wire.begin();
  Wire.setClock(400000);

  if (!ads.begin()) {
    Serial.println("FEHLER: ADS1115 nicht gefunden!");
    while (1) { delay(1000); }
  }
  Serial.println("ADS1115 gefunden.");

  ads.setGain(GAIN_ONE);
  ads.setDataRate(RATE_ADS1115_860SPS);
  ads.startADCReading(MUX_BY_CHANNEL[0], true);

  // ----- Lead-Off-Pins -----
  pinMode(LO_PLUS_PIN,  INPUT);
  pinMode(LO_MINUS_PIN, INPUT);

  // ----- Auto-Baseline -----
  Serial.println("Kalibriere Baseline (0,5 s)...");
  long sum = 0;
  int  count = 0;
  unsigned long start = millis();
  while (millis() - start < 500) {
    sum += ads.getLastConversionResults();
    count++;
    delay(2);
  }
  if (count > 0) baseline = sum / count;
  Serial.printf("Baseline: %d\n", baseline);

  // ----- SD-Karte -----
  //setupSD();

  // ----- BLE-Init -----
  BLEDevice::init("EKG-Holter");
  BLEDevice::setMTU(247);

  BLEServer* pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ     |
    BLECharacteristic::PROPERTY_NOTIFY   |
    BLECharacteristic::PROPERTY_WRITE    |
    BLECharacteristic::PROPERTY_WRITE_NR
  );
  pCharacteristic->setCallbacks(new MyCharCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("BLE Advertising gestartet als 'EKG-Holter'");
  Serial.printf("Paketgröße: %u Bytes\n", sizeof(EcgPacket));

  nextSampleTime = micros();
  lastFlushMs = millis();
}


// ============================================================================
//  LOOP
// ============================================================================

void loop() {
  if ((long)(micros() - nextSampleTime) >= 0) {
    nextSampleTime += 2000;   // 500 SPS

    int16_t adcValue = ads.getLastConversionResults();
    unsigned long now_ms = millis();

    float x   = (float)adcValue - (float)baseline;
    float bp  = bandpass.process(x);
    float dx  = differentiate(bp);
    float sq  = square(dx);
    float mwi = integrate(sq);
    detectPeakPT(mwi, now_ms);

    uint8_t status = 0;
    if (digitalRead(LO_PLUS_PIN))  status |= STATUS_LO_PLUS;
    if (digitalRead(LO_MINUS_PIN)) status |= STATUS_LO_MINUS;

    if (batchIndex == 0) {
      currentPacket.timestamp_ms = realTimestampMs(now_ms);
      currentPacket.status_flags = status;
    }

    currentPacket.samples[batchIndex] = adcValue;
    batchIndex++;

    if (batchIndex == 1) {
      EcgSample s;
      s.timestamp_ms = currentPacket.timestamp_ms;
      s.adc_value    = adcValue;
      s.hr_avg       = currentHR;
      s.status       = status;
      printSample(s);
    }

    if (batchIndex >= SAMPLES_PER_BATCH) {
      currentPacket.hr_avg       = currentHR;
      currentPacket.sample_count = SAMPLES_PER_BATCH;

      if (deviceConnected) {
        pCharacteristic->setValue((uint8_t*)&currentPacket, sizeof(currentPacket));
        pCharacteristic->notify();
      }

      if (sdAvailable && ekgFile) {
        ekgFile.write((uint8_t*)&currentPacket, sizeof(currentPacket));
        if (now_ms - lastFlushMs >= FLUSH_INTERVAL_MS) {
          ekgFile.flush();
          lastFlushMs = now_ms;
        }
      }

      batchIndex = 0;
    }
  }
}