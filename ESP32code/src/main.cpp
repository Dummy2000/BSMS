#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

volatile uint8_t currentHR = 0;

// ===== UUIDs =====
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ===== Pins =====
constexpr uint8_t LO_PLUS_PIN  = 35;
constexpr uint8_t LO_MINUS_PIN = 36;

// ===== Sampling =====
constexpr float SAMPLE_RATE_HZ        = 500.0f;
unsigned long   nextSampleTime;
constexpr unsigned long REFRACTORY_MS = 200;
constexpr uint8_t MWI_WINDOW          = 75;

// HR-Timeout: nach so vielen ms ohne neuen Peak wird HR auf 0 gesetzt
// und der Detektor reset-bereit. 3 s entspricht <20 bpm.
constexpr unsigned long HR_TIMEOUT_MS    = 3000;
constexpr unsigned long DETECTOR_RESET_MS = 3500;

// ===== ADS1115 =====
Adafruit_ADS1115 ads;
// Baseline: AD8232 gibt Vcc/2 als Ruhepegel aus.
// Wird beim Start automatisch kalibriert (siehe setup()).
int16_t baseline = 13200;

// ===== BLE Globals =====
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

// ===== Batch-Konfiguration =====
constexpr uint8_t SAMPLES_PER_BATCH = 20;

struct __attribute__((packed)) EcgPacket {
  uint32_t timestamp_ms;
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
  unsigned long timestamp_ms;
  int16_t       adc_value;
  uint8_t       hr_avg;
  uint8_t       status;
};


// ============================================================================
//  PAN-TOMPKINS DETEKTOR (gekapselt, mit reset()) - vom S3-Projekt übernommen
// ============================================================================

class PanTompkinsDetector {
private:
    float deriv_x1 = 0, deriv_x2 = 0, deriv_x3 = 0, deriv_x4 = 0;
    float mwi_buffer[MWI_WINDOW] = {0};
    uint8_t mwi_index = 0;
    float mwi_sum = 0;

    float SPK = 0;
    float NPK = 0;
    float threshold = 0;

    float candidate_value = 0;
    unsigned long candidate_time = 0;
    bool inPeak = false;

    unsigned long lastPeakTime_ms = 0;
    bool initialized = false;
    uint32_t initSampleCount = 0;

public:
    // Vollständiger Reset - wird bei HR-Timeout aufgerufen, damit sich
    // der Detektor nach Aussetzern nicht in einer schlechten Threshold-Lage festfrisst.
    void reset() {
        deriv_x1 = deriv_x2 = deriv_x3 = deriv_x4 = 0;
        for (uint8_t i = 0; i < MWI_WINDOW; i++) mwi_buffer[i] = 0;
        mwi_index = 0;
        mwi_sum = 0;
        SPK = NPK = threshold = 0;
        candidate_value = 0;
        candidate_time = 0;
        inPeak = false;
        lastPeakTime_ms = 0;
        initialized = false;
        initSampleCount = 0;
    }

    bool process(int16_t ecg_value, unsigned long now_ms) {
        float x = (float)ecg_value;

        // Differenzierer (5-Punkt-Stencil)
        float deriv = 0.125f * (2.0f*x + deriv_x1 - deriv_x3 - 2.0f*deriv_x4);
        deriv_x4 = deriv_x3; deriv_x3 = deriv_x2;
        deriv_x2 = deriv_x1; deriv_x1 = x;

        // Quadrieren
        float sq = deriv * deriv;

        // Moving-Window-Integrator (150 ms = 75 Samples)
        mwi_sum -= mwi_buffer[mwi_index];
        mwi_buffer[mwi_index] = sq;
        mwi_sum += sq;
        mwi_index = (mwi_index + 1) % MWI_WINDOW;
        float mwi = mwi_sum / (float)MWI_WINDOW;

        // Initialisierungs-Phase (erste 2 Sekunden)
        if (!initialized) {
            initSampleCount++;
            if (mwi > SPK) SPK = mwi;
            NPK = 0.5f * NPK + 0.5f * mwi;
            if (initSampleCount >= (uint32_t)(2.0f * SAMPLE_RATE_HZ)) {
                threshold = NPK + 0.25f * (SPK - NPK);
                initialized = true;
            }
            return false;
        }

        bool peakConfirmed = false;

        if (mwi > threshold) {
            // Lokales Maximum während wir über Threshold sind tracken
            if (!inPeak) {
                inPeak = true;
                candidate_value = mwi;
                candidate_time = now_ms;
            } else if (mwi > candidate_value) {
                candidate_value = mwi;
                candidate_time = now_ms;
            }
        } else if (inPeak) {
            // Wieder unter den Threshold gefallen -> Peak abschließen
            if (now_ms - lastPeakTime_ms > REFRACTORY_MS) {
                SPK = 0.125f * candidate_value + 0.875f * SPK;
                lastPeakTime_ms = candidate_time;
                peakConfirmed = true;
            } else {
                NPK = 0.125f * candidate_value + 0.875f * NPK;
            }
            threshold = NPK + 0.25f * (SPK - NPK);
            inPeak = false;
            candidate_value = 0;
        }

        // Stuck-Detection: Threshold halbieren wenn lange kein Peak.
        // Verhindert, dass sich der Detektor festfrisst.
        if (initialized && lastPeakTime_ms > 0 &&
            now_ms - lastPeakTime_ms > 1660) {
            threshold *= 0.5f;
            lastPeakTime_ms = now_ms - 1000;
        }

        return peakConfirmed;
    }

    float getThreshold() const { return threshold; }
    float getSPK() const { return SPK; }
    bool  isInitialized() const { return initialized; }
};

PanTompkinsDetector qrsDetector;


// ============================================================================
//  HR-Detection State (global, damit wir bei Timeout zurücksetzen können)
// ============================================================================

static unsigned long g_lastPeakWallTime = 0;
static float         g_hrSmoothed = 0.0f;

void resetHrState() {
    g_lastPeakWallTime = 0;
    g_hrSmoothed = 0.0f;
    currentHR = 0;
}

void detectPeak(int16_t value, unsigned long now_ms) {
    bool peakDetected = qrsDetector.process(value, now_ms);

    // ---- Stuck-Detection / HR-Timeout ----
    // Wenn lange kein Peak akzeptiert wurde, HR zurücksetzen und ggf.
    // den Detektor komplett resetten (das war der Stuck-Bug, der vorher
    // nur durch ESP-Neustart behebbar war).
    if (g_lastPeakWallTime > 0) {
        unsigned long since = now_ms - g_lastPeakWallTime;
        if (since > HR_TIMEOUT_MS && currentHR != 0) {
            currentHR = 0;
            g_hrSmoothed = 0.0f;
        }
        if (since > DETECTOR_RESET_MS) {
            qrsDetector.reset();
            g_lastPeakWallTime = 0;
            Serial.println("HR detector reset (timeout)");
        }
    }

    if (!peakDetected) return;

    // ---- Peak bestätigt ----
    if (g_lastPeakWallTime > 0) {
        unsigned long rr = now_ms - g_lastPeakWallTime;
        uint16_t hrInstant = (rr > 0) ? (60000 / rr) : 0;

        if (hrInstant >= 30 && hrInstant <= 220) {
            bool isOutlier = (g_hrSmoothed > 0 &&
                              abs((int)hrInstant - (int)g_hrSmoothed) > 30);
            if (!isOutlier) {
                if (g_hrSmoothed == 0) g_hrSmoothed = hrInstant;
                else g_hrSmoothed = 0.2f * hrInstant + 0.8f * g_hrSmoothed;
                currentHR = (uint8_t)g_hrSmoothed;
                // WICHTIG: lastPeak nur bei AKZEPTIERTEM Peak updaten.
                // Sonst wird das nächste RR-Intervall vom Outlier gemessen
                // und HR friert ein.
                g_lastPeakWallTime = now_ms;
            }
            // bei Outlier: g_lastPeakWallTime bleibt auf dem letzten echten Peak
        }
    } else {
        // erster Peak nach Init/Reset: nur merken
        g_lastPeakWallTime = now_ms;
    }

    Serial.printf("PEAK! HR=%u bpm  thr=%.0f  spk=%.0f\n",
                  currentHR, qrsDetector.getThreshold(), qrsDetector.getSPK());
}


// ============================================================================
//  Serial / BLE
// ============================================================================

void printSample(const EcgSample& s) {
  unsigned long totalSec = s.timestamp_ms / 1000;
  unsigned long ms_part  = s.timestamp_ms % 1000;
  unsigned long hours    = totalSec / 3600;
  unsigned long minutes  = (totalSec % 3600) / 60;
  unsigned long seconds  = totalSec % 60;

  const char* statusStr = "OK";
  if (s.status & STATUS_LO_PLUS && s.status & STATUS_LO_MINUS) statusStr = "BOTH-OFF";
  else if (s.status & STATUS_LO_PLUS)                          statusStr = "LO+OFF";
  else if (s.status & STATUS_LO_MINUS)                         statusStr = "LO-OFF";

  Serial.printf("%02lu:%02lu:%02lu.%03lu,%d,%03u,%s\n",
                hours, minutes, seconds, ms_part, s.adc_value, s.hr_avg, statusStr);
}

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("Client connected");
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("Client disconnected");
    BLEDevice::startAdvertising();
  }
};


// ============================================================================
//  SETUP
// ============================================================================

void setup() {
  Serial.begin(921600);
  delay(500);
  Serial.println("Start (ADS1115 + improved Pan-Tompkins)...");

  // ----- I²C + ADS1115 -----
  Wire.begin();
  Wire.setClock(400000);

  if (!ads.begin()) {
    Serial.println("FEHLER: ADS1115 nicht gefunden!");
    while (1) { delay(1000); }
  }
  Serial.println("ADS1115 gefunden.");

  ads.setGain(GAIN_ONE);                           // ±4.096V
  ads.setDataRate(RATE_ADS1115_860SPS);
  ads.startADCReading(MUX_BY_CHANNEL[0], true);    // Continuous Mode

  // ----- Lead-Off-Pins -----
  pinMode(LO_PLUS_PIN,  INPUT);
  pinMode(LO_MINUS_PIN, INPUT);

  // ----- Auto-Baseline: 0,5 s lang Mittelwert messen -----
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

  // ----- BLE-Init -----
  BLEDevice::init("EKG-Holter");
  BLEDevice::setMTU(247);

  BLEServer* pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("BLE Advertising gestartet als 'EKG-Holter'");
  Serial.printf("Paketgröße: %u Bytes\n", sizeof(EcgPacket));

  nextSampleTime = micros();
}


// ============================================================================
//  LOOP
// ============================================================================

void loop() {
  if ((long)(micros() - nextSampleTime) >= 0) {
    nextSampleTime += 2000;   // 500 SPS

    // ----- Sample vom ADS1115 holen -----
    int16_t adcValue = ads.getLastConversionResults();
    unsigned long now_ms = millis();

    // ----- DC-Offset entfernen für Pan-Tompkins -----
    // (PT sieht baseline-zentriertes Signal, wie im alten Holter-Code)
    int16_t adcCentered = adcValue - baseline;

    // ----- Peak-Detection -----
    detectPeak(adcCentered, now_ms);

    // ----- Lead-Off -----
    uint8_t status = 0;
    if (digitalRead(LO_PLUS_PIN))  status |= STATUS_LO_PLUS;
    if (digitalRead(LO_MINUS_PIN)) status |= STATUS_LO_MINUS;

    if (batchIndex == 0) {
      currentPacket.timestamp_ms = now_ms;
      currentPacket.status_flags = status;
    }

    // Im BLE-Paket schicken wir wie bisher den rohen ADC-Wert
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

      batchIndex = 0;
    }
  }
}