# ==============================================================================
# SISTEM MONITORING DAN OTOMASI BERBASIS IoT ESP32 (MONU)
# File Utama: main.py (All-in-One MicroPython Standalone)
#
# Seluruh fitur: Sensor, Aktuator (Relay Pompa & Buzzer), Wi-Fi, HTTP Server,
# dan Logika Otomasi terintegrasi dalam file ini tanpa modul eksternal.
# 100% Kompatibel dengan parser MicroPython (Bebas SyntaxError).
# ==============================================================================

import machine
import dht
import network
import usocket as socket
import ujson as json
import utime as time
import gc

# ==============================================================================
# 1. PENGATURAN WI-FI & IDENTITAS PERANGKAT
# ==============================================================================
# Silakan sesuaikan SSID dan Password Wi-Fi / Hotspot Anda:
WIFI_SSID     = "piraeyy"
WIFI_PASSWORD = "aeliluyy"

DEVICE_ID     = "monu-node-1"
DEVICE_NAME   = "ESP32 MONU Node"
SERVER_PORT   = 80

WIFI_CHECK_INTERVAL_MS = 10000   # Cek koneksi Wi-Fi tiap 10 detik
WIFI_TIMEOUT_SEC       = 15      # Batas waktu percobaan awal koneksi

# ==============================================================================
# 2. KONFIGURASI PIN GPIO (SESUAI PRD SEKSI 4)
# ==============================================================================
PIN_MAX6675_SCK   = 18   # MAX6675 SPI Clock (SCK)
PIN_MAX6675_SO    = 19   # MAX6675 SPI Data Out / MISO (SO)
PIN_MAX6675_CS    = 5    # MAX6675 SPI Chip Select (CS)
PIN_MQ2           = 34   # MQ-2 Analog Out (AO) - ADC1_CH6 (Input Only)
PIN_DHT11         = 4    # DHT11 DATA - Digital I/O (1-Wire)
PIN_SOIL_MOISTURE = 35   # Soil Moisture Analog Out (AO) - ADC1_CH7 (Input Only)
PIN_RELAY         = 26   # Relay Module IN - Digital Output Pompa
PIN_BUZZER        = 27   # Buzzer IO - Digital / PWM Output

# ==============================================================================
# 3. PENGATURAN AKTUATOR (RELAY POMPA & BUZZER)
# ==============================================================================
# Konfigurasi Relay:
# Sebagian besar modul relay bersifat Active-LOW:
#   True  = Active-LOW (0 = Pompa ON, 1 = Pompa OFF)
#   False = Active-HIGH (1 = Pompa ON, 0 = Pompa OFF)
RELAY_ACTIVE_LOW     = True
PUMP_MAX_RUNTIME_SEC = 20   # Pengaman: Maksimal pompa menyala berturut-turut (20 detik)
PUMP_COOLDOWN_SEC    = 15   # Jeda istirahat wajib setelah pompa menyala (15 detik)

# Konfigurasi Buzzer 3 Pin:
# - Active Buzzer: Menghasilkan bunyi dengan sinyal Digital HIGH/LOW atau pulsa cepat
# - Passive Buzzer: Menghasilkan nada nyaring dengan sinyal frekuensi PWM
# PENTING: BUZZER_USE_PWM diaktifkan (True) dengan duty 50% dan frekuensi resonansi 2730 Hz
# agar menghasilkan volume bunyi MAKSIMAL dan KENCANG untuk buzzer pasif maupun aktif.
BUZZER_ACTIVE_HIGH   = True
BUZZER_USE_PWM       = True   # True = PWM duty 50% optimal (suara paling kencang)
BUZZER_PWM_FREQ      = 2730   # Frekuensi resonansi puncak diafragma piezo (2730 Hz = dB tertinggi)
BUZZER_SIREN_MODE    = True   # True = Efek sirine dua nada menusuk (2600 Hz & 3300 Hz) agar suara sangat keras

# ==============================================================================
# 4. AMBANG BATAS & KALIBRASI SENSOR
# ==============================================================================
# A. Soil Moisture (Sensor Kapasitif / Resistif)
SOIL_DRY_ADC             = 3300   # Nilai ADC saat tanah kering (0%)
SOIL_WET_ADC             = 1300   # Nilai ADC saat tanah basah maksimal (100%)
SOIL_TRIGGER_DRY_PERCENT = 30.0   # Persen tanah kering (Pompa ON)
SOIL_TARGET_WET_PERCENT  = 65.0   # Persen target kelembapan (Pompa OFF)

# B. DHT11 (Suhu & Kelembapan Udara)
DHT_TEMP_HIGH_THRESHOLD  = 36.0   # Suhu udara tinggi (°C) -> Pompa ON & Buzzer ON
DHT_TEMP_SAFE_THRESHOLD  = 32.0   # Suhu udara kembali normal (°C) -> OFF
DHT_READ_INTERVAL_MS     = 2500   # Jeda minimum pembacaan DHT11 (2.5 detik)

# C. MQ-2 (Deteksi Gas / Asap)
# PRD v2.2 FR-06: Gas >= 2500 ADC -> Buzzer ON, Pompa TIDAK aktif karena gas saja!
MQ2_GAS_THRESHOLD        = 2500   # Ambang batas deteksi gas (ADC mentah) -> Buzzer ON saja
MQ2_WARMUP_SEC           = 20     # Waktu pemanasan awal sensor MQ-2 saat startup

# D. Thermocouple K-Type + MAX6675 (PRD v2.2 FR-05)
# Probe NORMAL   : suhu naik (>= 50°C)      -> Pompa ON + Buzzer ON
# Probe TERBALIK : suhu turun (<= 28°C)      -> juga Pompa ON + Buzzer ON
#   (Probe terbalik membaca RENDAH saat sebenarnya PANAS, misal saat dibakar korek
#    bacaan turun dari 27°C -> 0°C, sehingga <= THERMO_FIRE_REVERSED = panas nyata)
THERMO_FIRE_THRESHOLD      = 50.0 # Probe normal: suhu tinggi (°C) -> Pompa ON & Buzzer ON
THERMO_FIRE_REVERSED       = 10.0 # Probe terbalik: jika bacaan <= 10°C -> Pompa ON & Buzzer ON
THERMO_TEMP_HIGH_THRESHOLD = 50.0 # Alias kompatibilitas threshold suhu tinggi
THERMO_TEMP_SAFE_THRESHOLD = 40.0 # Suhu thermocouple kembali aman (°C) -> OFF

# Waktu Siklus Pemantauan
SENSOR_READ_INTERVAL_MS  = 1000   # Baca sensor & evaluasi logika setiap 1 detik
SERIAL_LOG_INTERVAL_MS   = 3000   # Cetak Serial Monitor setiap 3 detik


# ==============================================================================
# 5. KELAS AKTUATOR: KONTROLER RELAY POMPA AIR
# ==============================================================================
class PumpController:
    def __init__(self, pin_num=PIN_RELAY, active_low=RELAY_ACTIVE_LOW):
        self.pin_num = pin_num
        self.active_low = active_low
        self.is_active = False
        self.start_ticks = 0
        self.last_stop_ticks = 0
        self.active_reasons = []

        self.off_val = 1 if self.active_low else 0
        self.on_val  = 0 if self.active_low else 1

        try:
            # Pengaman boot: Pin langsung diberi nilai MATI saat inisialisasi
            self.pin = machine.Pin(self.pin_num, machine.Pin.OUT, value=self.off_val)
            self.pin.value(self.off_val)
            relay_type_str = "Active-Low" if active_low else "Active-High"
            print("[Actuator] Relay Pompa GPIO " + str(pin_num) + " siap (" + relay_type_str + ", Status: OFF)")
        except Exception as e:
            print("[Actuator] Gagal inisialisasi relay: " + str(e))
            self.pin = None

    def turn_on(self, reason="Manual"):
        if not self.pin:
            return False
        if not self.is_active:
            self.pin.value(self.on_val)
            self.is_active = True
            self.start_ticks = time.ticks_ms()
            print("[Pump] >>> POMPA AIR DIAKTIFKAN (ON) | Alasan: " + str(reason))
        return True

    def turn_off(self, reason="Kondisi normal"):
        if not self.pin:
            return False
        if self.is_active:
            self.pin.value(self.off_val)
            self.is_active = False
            self.last_stop_ticks = time.ticks_ms()
            self.active_reasons = []
            print("[Pump] <<< POMPA AIR DIMATIKAN (OFF) | Alasan: " + str(reason))
        return True

    def get_runtime_seconds(self):
        if not self.is_active:
            return 0
        return time.ticks_diff(time.ticks_ms(), self.start_ticks) // 1000

    def get_cooldown_remaining_sec(self):
        if self.is_active or self.last_stop_ticks == 0:
            return 0
        elapsed = time.ticks_diff(time.ticks_ms(), self.last_stop_ticks) // 1000
        rem = PUMP_COOLDOWN_SEC - elapsed
        return max(0, rem)

    def get_status(self):
        return {
            "name": "Pompa Air (Relay)",
            "gpio": self.pin_num,
            "active": self.is_active,
            "state": 1 if self.is_active else 0,
            "state_label": "ON" if self.is_active else "OFF",
            "active_reasons": self.active_reasons,
            "runtime_seconds": self.get_runtime_seconds(),
            "in_cooldown": self.get_cooldown_remaining_sec() > 0,
            "cooldown_remaining_sec": self.get_cooldown_remaining_sec()
        }


# ==============================================================================
# 6. KELAS AKTUATOR: KONTROLER BUZZER 3-PIN
# ==============================================================================
class BuzzerController:
    def __init__(self, pin_num=PIN_BUZZER, active_high=BUZZER_ACTIVE_HIGH, use_pwm=BUZZER_USE_PWM):
        self.pin_num = pin_num
        self.active_high = active_high
        self.use_pwm = use_pwm
        self.is_active = False
        self.is_emergency = False
        self.active_reasons = []
        self.pwm = None
        self.last_siren_ticks = 0
        self.siren_state = False

        self.on_val = 1 if self.active_high else 0
        self.off_val = 0 if self.active_high else 1

        try:
            self.pin = machine.Pin(self.pin_num, machine.Pin.OUT, value=self.off_val)
            self.pin.value(self.off_val)
            buzzer_type_str = "PWM (Suara Kencang)" if use_pwm else "Digital DC"
            print("[Actuator] Buzzer GPIO " + str(pin_num) + " siap (" + buzzer_type_str + ", Status: OFF)")
        except Exception as e:
            print("[Actuator] Gagal inisialisasi buzzer: " + str(e))
            self.pin = None

    def _start_pwm(self, freq=BUZZER_PWM_FREQ):
        if not self.pin:
            return
        try:
            if self.pwm is None:
                self.pwm = machine.PWM(machine.Pin(self.pin_num))
            self.pwm.freq(freq)
            try:
                # 50% square-wave duty cycle (32768 dari 65535) untuk amplitudo akustik maksimal
                self.pwm.duty_u16(32768)
            except (AttributeError, ValueError):
                # Fallback untuk MicroPython lama (rentang 0-1023)
                self.pwm.duty(512)
        except Exception as e:
            print("[Buzzer] Error PWM: " + str(e))
            try:
                self.pin.value(self.on_val)
            except:
                pass

    def turn_on(self, reason="Alarm", emergency=False):
        if not self.pin:
            return False
        self.is_emergency = emergency
        if not self.is_active:
            self.is_active = True
            self.last_siren_ticks = time.ticks_ms()
            self.siren_state = False
            if self.use_pwm:
                freq = 3300 if emergency else BUZZER_PWM_FREQ
                self._start_pwm(freq)
            else:
                self.pin.value(self.on_val)
            prefix = "[EMERGENCY SIREN]" if emergency else "[Buzzer]"
            print(prefix + " >>> BUZZER MENYALA KENCANG (ON) | Alasan: " + str(reason))
        else:
            if emergency and not self.is_emergency:
                self.is_emergency = True
        return True

    def update(self):
        """
        Modulasi frekuensi sirine agar suara piezo jauh lebih menusuk, nyaring,
        dan terdengar sangat kencang menembus kebisingan ruangan.
        """
        if not self.is_active or not self.use_pwm or not BUZZER_SIREN_MODE:
            return

        now = time.ticks_ms()
        # Sirine api darurat modulasi cepat (120ms), peringatan standar (220ms)
        interval = 120 if self.is_emergency else 220
        if time.ticks_diff(now, self.last_siren_ticks) >= interval:
            self.last_siren_ticks = now
            self.siren_state = not self.siren_state
            # Berganti antara 2600 Hz dan 3300 Hz (resonansi puncak diafragma piezo)
            target_freq = 3300 if self.siren_state else 2600
            try:
                if self.pwm:
                    self.pwm.freq(target_freq)
            except:
                pass

    def turn_off(self, reason="Normal"):
        if not self.pin:
            return False
        if self.is_active:
            if self.pwm:
                try:
                    self.pwm.deinit()
                except:
                    pass
                self.pwm = None
            try:
                self.pin = machine.Pin(self.pin_num, machine.Pin.OUT, value=self.off_val)
                self.pin.value(self.off_val)
            except:
                pass
            self.is_active = False
            self.is_emergency = False
            self.active_reasons = []
            print("[Buzzer] <<< BUZZER MATI (OFF) | Alasan: " + str(reason))
        return True

    def beep(self, duration_ms=100):
        """Bunyi 'beep' singkat untuk feedback startup dengan volume penuh."""
        self.turn_on("Beep Feedback", emergency=False)
        time.sleep_ms(duration_ms)
        self.turn_off("Beep End")

    def get_status(self):
        return {
            "name": "Buzzer Peringatan",
            "gpio": self.pin_num,
            "active": self.is_active,
            "emergency": self.is_emergency,
            "state_label": "ON" if self.is_active else "OFF",
            "active_reasons": self.active_reasons
        }


# ==============================================================================
# 7. KELAS PEMBACAAN SELURUH SENSOR
# ==============================================================================
class SensorManager:
    def __init__(self, boot_ticks):
        self.boot_ticks = boot_ticks

        # 1. ADC Soil Moisture (GPIO 35)
        try:
            self.adc_soil = machine.ADC(machine.Pin(PIN_SOIL_MOISTURE))
            self.adc_soil.atten(machine.ADC.ATTN_11DB)
            print("[Sensors] Soil Moisture ADC GPIO " + str(PIN_SOIL_MOISTURE) + " siap.")
        except Exception as e:
            print("[Sensors] Gagal init ADC Soil: " + str(e))
            self.adc_soil = None

        # 2. DHT11 (GPIO 4)
        try:
            self.dht_sensor = dht.DHT11(machine.Pin(PIN_DHT11))
            print("[Sensors] DHT11 GPIO " + str(PIN_DHT11) + " siap.")
        except Exception as e:
            print("[Sensors] Gagal init DHT11: " + str(e))
            self.dht_sensor = None
        self.dht_last_ticks = 0
        self.dht_cached_temp = None
        self.dht_cached_hum = None

        # 3. ADC MQ-2 (GPIO 34)
        try:
            self.adc_mq2 = machine.ADC(machine.Pin(PIN_MQ2))
            self.adc_mq2.atten(machine.ADC.ATTN_11DB)
            print("[Sensors] MQ-2 ADC GPIO " + str(PIN_MQ2) + " siap.")
        except Exception as e:
            print("[Sensors] Gagal init ADC MQ-2: " + str(e))
            self.adc_mq2 = None

        # 4. MAX6675 SPI Thermocouple (SCK=18, SO=19, CS=5)
        try:
            self.pin_sck = machine.Pin(PIN_MAX6675_SCK, machine.Pin.OUT)
            self.pin_cs  = machine.Pin(PIN_MAX6675_CS, machine.Pin.OUT)
            self.pin_so  = machine.Pin(PIN_MAX6675_SO, machine.Pin.IN)
            self.pin_cs.value(1)   # Idle HIGH
            self.pin_sck.value(0)  # Idle LOW
            self.thermo_ok = True
            print("[Sensors] MAX6675 SPI siap (SCK=" + str(PIN_MAX6675_SCK) + ", SO=" + str(PIN_MAX6675_SO) + ", CS=" + str(PIN_MAX6675_CS) + ").")
        except Exception as e:
            print("[Sensors] Gagal init MAX6675: " + str(e))
            self.thermo_ok = False

        self.data_cache = {}
        self.last_thermo_val = None

    def read_soil(self):
        """Membaca ADC kelembapan tanah, menghitung persentase, dan klasifikasi kering/lembab/basah."""
        if not self.adc_soil:
            return {"raw": None, "raw_adc": None, "percentage": None, "status": "error", "error": "ADC belum aktif"}
        try:
            samples = [self.adc_soil.read() for _ in range(5)]
            raw = sum(samples) // len(samples)

            if SOIL_DRY_ADC != SOIL_WET_ADC:
                pct = ((SOIL_DRY_ADC - raw) / (SOIL_DRY_ADC - SOIL_WET_ADC)) * 100.0
            else:
                pct = 0.0

            pct = max(0.0, min(100.0, pct))
            pct_rounded = round(pct, 1)

            # Klasifikasi kondisi tanah sesuai PRD
            if pct_rounded <= SOIL_TRIGGER_DRY_PERCENT:
                status_label = "DRY"
            elif pct_rounded >= SOIL_TARGET_WET_PERCENT:
                status_label = "WET"
            else:
                status_label = "MOIST"

            return {
                "raw": raw,
                "raw_adc": raw,
                "percentage": pct_rounded,
                "status": status_label,
                "soil_dry": pct_rounded <= SOIL_TRIGGER_DRY_PERCENT,
                "unit": "ADC",
                "error": None
            }
        except Exception as e:
            return {"raw": None, "raw_adc": None, "percentage": None, "status": "error", "soil_dry": False, "error": str(e)}

    def read_dht(self):
        """Membaca suhu (°C) dan kelembapan (%RH) dari DHT11 dengan proteksi interval."""
        if not self.dht_sensor:
            return {"temperature": None, "humidity": None, "status": "error", "error": "Sensor belum terpasang"}

        now = time.ticks_ms()
        if self.dht_cached_temp is not None and time.ticks_diff(now, self.dht_last_ticks) < DHT_READ_INTERVAL_MS:
            is_high = self.dht_cached_temp >= DHT_TEMP_HIGH_THRESHOLD
            return {
                "temperature": self.dht_cached_temp,
                "humidity": self.dht_cached_hum,
                "status": "HIGH" if is_high else "NORMAL",
                "temp_unit": "°C",
                "humidity_unit": "%RH",
                "error": None
            }

        try:
            self.dht_sensor.measure()
            temp = self.dht_sensor.temperature()
            hum = self.dht_sensor.humidity()

            if temp is None or hum is None or (temp == 0 and hum == 0):
                raise ValueError("Data pembacaan DHT11 tidak valid")

            self.dht_cached_temp = temp
            self.dht_cached_hum = hum
            self.dht_last_ticks = now

            is_high = temp >= DHT_TEMP_HIGH_THRESHOLD
            return {
                "temperature": temp,
                "humidity": hum,
                "status": "HIGH" if is_high else "NORMAL",
                "temp_unit": "°C",
                "humidity_unit": "%RH",
                "error": None
            }
        except (OSError, Exception) as e:
            if self.dht_cached_temp is not None and time.ticks_diff(now, self.dht_last_ticks) < 10000:
                is_high = self.dht_cached_temp >= DHT_TEMP_HIGH_THRESHOLD
                return {
                    "temperature": self.dht_cached_temp,
                    "humidity": self.dht_cached_hum,
                    "status": "HIGH" if is_high else "NORMAL",
                    "temp_unit": "°C",
                    "humidity_unit": "%RH",
                    "error": None
                }
            return {"temperature": None, "humidity": None, "status": "error", "error": "DHT11 gagal baca (" + str(e) + ")"}

    def read_mq2(self):
        """Membaca nilai analog ADC MQ-2 (0-4095) dan menangani masa pemanasan sensor."""
        if not self.adc_mq2:
            return {"raw": None, "raw_adc": None, "threshold": MQ2_GAS_THRESHOLD, "gas_detected": False, "status": "error"}

        uptime_sec = time.ticks_diff(time.ticks_ms(), self.boot_ticks) // 1000
        is_warming = uptime_sec < MQ2_WARMUP_SEC

        try:
            samples = [self.adc_mq2.read() for _ in range(5)]
            raw = sum(samples) // len(samples)

            if is_warming:
                rem = MQ2_WARMUP_SEC - uptime_sec
                return {
                    "raw": raw,
                    "raw_adc": raw,
                    "threshold": MQ2_GAS_THRESHOLD,
                    "gas_detected": False,
                    "status": "WARMING_UP (" + str(rem) + "s)",
                    "error": None
                }

            is_gas = raw >= MQ2_GAS_THRESHOLD
            return {
                "raw": raw,
                "raw_adc": raw,
                "threshold": MQ2_GAS_THRESHOLD,
                "gas_detected": is_gas,
                "status": "DETECTED" if is_gas else "NORMAL",
                "unit": "ADC",
                "error": None
            }
        except Exception as e:
            return {"raw": None, "raw_adc": None, "threshold": MQ2_GAS_THRESHOLD, "gas_detected": False, "status": "error", "error": str(e)}

    def read_thermocouple(self):
        """
        Pembacaan SPI Bitbang MAX6675 sesuai datasheet:
        - CS ditarik LOW
        - 16 pulsa clock SCK membaca 16-bit MSB-to-LSB dari SO
        - Bit D15: Dummy 0
        - Bit D14..D3: 12-bit besaran suhu (* 0.25 °C)
        - Bit D2: Open Circuit (1 jika kabel probe terputus)

        PANDUAN FISIK JIKA SUHU TURUN SAAT DIPANASKAN:
        Jika saat probe dipanaskan api suhunya turun dari 30°C menjadi 1°C:
        >>> KABEL MERAH DAN BIRU/KUNING TERPASANG TERBALIK PADA TERMINAL BAUT MAX6675! <<<
        Solusi: Tukar posisi kedua kabel probe pada terminal baut modul MAX6675.
        """
        if not self.thermo_ok:
            return {"temperature": None, "status": "error", "error": "SPI MAX6675 belum terinisialisasi"}

        try:
            self.pin_cs.value(0)
            time.sleep_us(10)
            data = 0
            for _ in range(16):
                self.pin_sck.value(1)
                time.sleep_us(5)
                data = (data << 1) | self.pin_so.value()
                self.pin_sck.value(0)
                time.sleep_us(5)
            self.pin_cs.value(1)

            # Jika kabel SPI lepas (semua 0 atau semua 1)
            if data == 0 or data == 0xFFFF:
                return {"temperature": None, "status": "error", "error": "Modul MAX6675 tidak merespons (Cek kabel SPI)"}

            # Bit D2 == 1: Thermocouple Open Circuit (kabel probe lepas)
            if data & 0x0004:
                return {"temperature": None, "status": "error", "error": "Thermocouple Open Circuit (Probe terputus)"}

            # Ekstrak 12-bit suhu (bit 3 s/d 14) dikali resolusi 0.25°C
            raw_temp = (data >> 3) & 0x0FFF
            temp_c = raw_temp * 0.25

            # Deteksi diagnostik jika suhu turun abnormal
            if self.last_thermo_val is not None:
                if temp_c < (self.last_thermo_val - 10.0) and temp_c < 10.0:
                    print("[WARNING] Suhu thermocouple anjlok drastis! Periksa polaritas kabel probe T+ dan T-.")

            self.last_thermo_val = temp_c

            # Deteksi api:
            # - Probe NORMAL   : suhu tinggi >= THERMO_FIRE_THRESHOLD (50°C)
            # - Probe TERBALIK : suhu rendah <= THERMO_FIRE_REVERSED  (28°C)
            #   (saat dibakar, probe terbalik membaca mendekati 0°C)
            is_fire = (temp_c >= THERMO_FIRE_THRESHOLD) or (temp_c <= THERMO_FIRE_REVERSED)
            is_high = is_fire

            hex_str = "0x" + ("0000" + hex(data)[2:])[-4:].upper()

            return {
                "temperature": round(temp_c, 2),
                "status": "FIRE_ALERT" if is_fire else ("HIGH" if is_high else "NORMAL"),
                "fire_detected": is_fire,
                "raw_hex": hex_str,
                "unit": "°C",
                "error": None
            }
        except Exception as e:
            return {"temperature": None, "status": "error", "error": str(e)}

    def read_all(self):
        self.data_cache = {
            "soil_moisture": self.read_soil(),
            "dht11": self.read_dht(),
            "mq2": self.read_mq2(),
            "thermocouple": self.read_thermocouple()
        }
        return self.data_cache

    def get_readings(self):
        if not self.data_cache:
            return self.read_all()
        return self.data_cache


# ==============================================================================
# 8. KELAS KONEKSI WI-FI (DHCP & RECONNECT OTOMATIS)
# ==============================================================================
class WiFiManager:
    def __init__(self, ssid=WIFI_SSID, password=WIFI_PASSWORD):
        self.ssid = ssid
        self.password = password
        self.last_check = 0
        self.wlan = None
        self._init_wlan()

    def _init_wlan(self):
        """Inisialisasi interface STA dengan manajemen RAM ketat agar terhindar dari WiFi Out of Memory."""
        gc.collect()
        # Matikan Access Point (AP_IF) jika aktif agar memori internal Wi-Fi lega
        try:
            ap = network.WLAN(network.AP_IF)
            if ap.active():
                ap.active(False)
        except:
            pass
        gc.collect()

        for attempt in range(2):
            try:
                self.wlan = network.WLAN(network.STA_IF)
                return True
            except OSError as e:
                print("[Wi-Fi] Percobaan " + str(attempt + 1) + " gagal (" + str(e) + "), bersihkan RAM...")
                gc.collect()
                time.sleep_ms(250)
            except Exception as e:
                print("[Wi-Fi] Gagal inisialisasi WLAN: " + str(e))
                break
        self.wlan = None
        return False

    def connect(self, timeout_s=WIFI_TIMEOUT_SEC):
        if self.wlan is None:
            if not self._init_wlan():
                print("[Wi-Fi] WLAN tidak tersedia (memori penuh). Sistem tetap berjalan offline.")
                return False

        gc.collect()
        try:
            if not self.wlan.active():
                self.wlan.active(True)
        except OSError as e:
            print("[Wi-Fi] Gagal mengaktifkan Wi-Fi (" + str(e) + "). Sistem tetap berjalan lokal.")
            return False
        except Exception as e:
            print("[Wi-Fi] Error active(True): " + str(e))
            return False

        try:
            self.wlan.config(dhcp_hostname="monu-esp32")
        except:
            pass

        if self.wlan.isconnected():
            return True

        print("[Wi-Fi] Menghubungkan ke '" + str(self.ssid) + "'...")
        try:
            self.wlan.connect(self.ssid, self.password)
        except Exception as e:
            print("[Wi-Fi] Error connect: " + str(e))
            return False

        start = time.time()
        dots = 0
        while not self.wlan.isconnected():
            if time.time() - start > timeout_s:
                print("\n[Wi-Fi] Waktu habis (" + str(timeout_s) + "s). Sistem tetap berjalan lokal.")
                return False
            time.sleep_ms(300)
            print(".", end="")
            dots += 1
            if dots % 30 == 0:
                print()

        ip, sub, gw, dns = self.wlan.ifconfig()
        print("\n" + "=" * 50)
        print("          ESP32 TERHUBUNG KE JARINGAN WI-FI       ")
        print("=" * 50)
        print(" SSID         : " + str(self.ssid))
        print(" IP Address   : " + str(ip))
        print(" Subnet Mask  : " + str(sub))
        print(" Gateway      : " + str(gw))
        print("=" * 50 + "\n")
        return True

    def check_and_reconnect(self):
        if self.wlan is None:
            return False
        now = time.ticks_ms()
        if time.ticks_diff(now, self.last_check) < WIFI_CHECK_INTERVAL_MS:
            return self.wlan.isconnected()
        self.last_check = now

        if not self.wlan.isconnected():
            print("[Wi-Fi] Koneksi terputus! Mencoba menyambung ulang di background...")
            try:
                gc.collect()
                if not self.wlan.active():
                    self.wlan.active(True)
                self.wlan.connect(self.ssid, self.password)
            except Exception as e:
                print("[Wi-Fi] Reconnect error: " + str(e))
            return False
        return True

    def is_connected(self):
        if self.wlan is None:
            return False
        return self.wlan.isconnected()

    def get_ip(self):
        if self.wlan is None or not self.wlan.isconnected():
            return "0.0.0.0"
        return self.wlan.ifconfig()[0]

    def get_info(self):
        conn = False if self.wlan is None else self.wlan.isconnected()
        ip, sub, gw, dns = ("0.0.0.0", "0.0.0.0", "0.0.0.0", "0.0.0.0")
        mac_str = "00:00:00:00:00:00"
        rssi = None
        if conn:
            try:
                ip, sub, gw, dns = self.wlan.ifconfig()
                mac_bytes = self.wlan.config("mac")
                mac_str = ":".join("%02X" % b for b in mac_bytes)
                rssi = self.wlan.status("rssi")
            except:
                pass
        return {
            "connected": conn,
            "status": "terhubung" if conn else "terputus",
            "ssid": self.ssid,
            "ip_address": ip,
            "subnet_mask": sub,
            "gateway": gw,
            "dns": dns,
            "mac_address": mac_str,
            "rssi": rssi
        }


# ==============================================================================
# 9. KELAS HTTP REST API & WEB DASHBOARD (PORT 80)
# ==============================================================================
class HttpServer:
    def __init__(self, sensor_mgr, pump_ctrl, buzzer_ctrl, wifi_mgr, boot_ticks, port=SERVER_PORT):
        self.sensor_mgr  = sensor_mgr
        self.pump_ctrl   = pump_ctrl
        self.buzzer_ctrl = buzzer_ctrl
        self.wifi_mgr    = wifi_mgr
        self.boot_ticks  = boot_ticks
        self.port        = port
        self.sock        = None

    def start(self):
        try:
            addr = socket.getaddrinfo("0.0.0.0", self.port)[0][-1]
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.sock.bind(addr)
            self.sock.listen(4)
            self.sock.settimeout(0.1)  # Non-blocking 100ms
            print("[API] Server aktif pada port " + str(self.port))
            return True
        except Exception as e:
            print("[API] Gagal bind socket port " + str(self.port) + ": " + str(e))
            self.sock = None
            return False

    def get_uptime_human(self):
        sec = time.ticks_diff(time.ticks_ms(), self.boot_ticks) // 1000
        h = sec // 3600
        m = (sec % 3600) // 60
        s = sec % 60
        return str(h) + "j " + str(m) + "m " + str(s) + "d"

    def build_prd_format(self):
        """Menghasilkan format data konsisten sesuai PRD Seksi 9."""
        s = self.sensor_mgr.get_readings()
        dht_s = s.get("dht11", {})
        soil  = s.get("soil_moisture", {})
        mq2   = s.get("mq2", {})
        tc    = s.get("thermocouple", {})

        is_dry = soil.get("soil_dry", False)
        gas_det = mq2.get("gas_detected", False)
        fire_det = tc.get("fire_detected", False)
        pump_on = self.pump_ctrl.is_active
        buzzer_on = self.buzzer_ctrl.is_active

        sys_status = "alarm" if (gas_det or fire_det or pump_on or buzzer_on) else "normal"

        return {
            "temperature": dht_s.get("temperature"),
            "humidity": dht_s.get("humidity"),
            "thermocouple_temperature": tc.get("temperature"),
            "gas_value": mq2.get("raw"),
            "soil_value": soil.get("raw"),
            "soil_moisture": soil.get("percentage"),
            "gas_detected": gas_det,
            "fire_detected": fire_det,
            "soil_dry": is_dry,
            "pump_status": pump_on,
            "buzzer_status": buzzer_on,
            "system_status": sys_status
        }

    def build_full_status(self):
        """Format lengkap kompatibel dengan PRD dan Flutter App."""
        prd = self.build_prd_format()
        sensors = self.sensor_mgr.get_readings()
        pump_info = self.pump_ctrl.get_status()
        buzzer_info = self.buzzer_ctrl.get_status()
        wifi_info = self.wifi_mgr.get_info()
        uptime_sec = time.ticks_diff(time.ticks_ms(), self.boot_ticks) // 1000

        full = {
            "device": "ESP32",
            "device_id": DEVICE_ID,
            "device_name": DEVICE_NAME,
            "status": "online" if wifi_info["connected"] else "disconnected",
            "device_status": "online" if wifi_info["connected"] else "disconnected",
            "wifi_connected": wifi_info["connected"],
            "ip_address": wifi_info["ip_address"],
            "uptime_seconds": uptime_sec,
            "uptime_human": self.get_uptime_human(),
            "free_ram_bytes": gc.mem_free(),
            "wifi": wifi_info,
            "sensors": sensors,
            "pump": {
                "active": pump_info["active"],
                "reasons": pump_info["active_reasons"],
                "runtime_seconds": pump_info["runtime_seconds"],
                "in_cooldown": pump_info["in_cooldown"]
            },
            "buzzer": buzzer_info,
            "actuators": {
                "relay": pump_info,
                "buzzer": buzzer_info
            }
        }
        full.update(prd)
        return full

    def render_html(self):
        """
        Membangun Web Dashboard HTML sederhana dan bebas error sintaks parser MicroPython.
        Menggunakan penggabungan string murni tanpa nested f-strings.
        """
        full = self.build_full_status()
        s = full.get("sensors", {})
        soil = s.get("soil_moisture", {})
        dht_s = s.get("dht11", {})
        mq2 = s.get("mq2", {})
        tc  = s.get("thermocouple", {})
        p   = full.get("pump", {})
        b   = full.get("buzzer", {})
        w   = full.get("wifi", {})

        p_active = p.get("active", False)
        pump_color = "#22c55e" if p_active else "#94a3b8"
        pump_label = "AKTIF (MENYIRAM)" if p_active else "STANDBY (MATI)"

        b_active = b.get("active", False)
        buzzer_color = "#f43f5e" if b_active else "#94a3b8"
        buzzer_label = "BUNYI (ALARM)" if b_active else "STANDBY (SENYAP)"

        soil_dry = soil.get("soil_dry", False)
        soil_badge_cls = "bg-warn" if soil_dry else "bg-on"
        soil_pct_val = str(soil.get("percentage", "-"))
        soil_raw_val = str(soil.get("raw", "-"))
        soil_stat_val = str(soil.get("status", "NORMAL"))

        dht_stat = str(dht_s.get("status", "NORMAL"))
        dht_badge_cls = "bg-danger" if dht_stat == "HIGH" else "bg-on"
        dht_temp_val = str(dht_s.get("temperature", "-"))
        dht_hum_val = str(dht_s.get("humidity", "-"))

        tc_stat = str(tc.get("status", "NORMAL"))
        tc_fire = tc.get("fire_detected", False)
        tc_badge_cls = "bg-danger" if (tc_stat in ("error", "HIGH", "FIRE_ALERT") or tc_fire) else "bg-on"
        tc_temp_val = str(tc.get("temperature", "-"))
        tc_hex_val = str(tc.get("raw_hex", "-"))
        tc_err = tc.get("error")
        tc_err_block = ("<p class='sub' style='color:#f43f5e'>" + str(tc_err) + "</p>") if tc_err else ""

        mq2_gas = mq2.get("gas_detected", False)
        mq2_badge_cls = "bg-danger" if mq2_gas else "bg-on"
        mq2_raw_val = str(mq2.get("raw", "-"))
        mq2_stat_val = str(mq2.get("status", "NORMAL"))

        p_runtime = str(p.get("runtime_seconds", 0))
        p_reasons = p.get("reasons", [])
        p_reasons_str = ", ".join(p_reasons) if p_reasons else ""
        p_reasons_block = ("<p class='sub' style='color:#fbbf24'>Pemicu: " + p_reasons_str + "</p>") if p_reasons_str else ""

        b_reasons = b.get("active_reasons", [])
        b_reasons_str = ", ".join(b_reasons) if b_reasons else ""
        b_reasons_block = ("<p class='sub' style='color:#f43f5e'>Pemicu: " + b_reasons_str + "</p>") if b_reasons_str else ""

        uptime_str = str(full.get("uptime_human", "-"))
        ip_str = str(w.get("ip_address", "0.0.0.0"))
        cooldown_str = str(self.pump_ctrl.get_cooldown_remaining_sec())

        html = (
            "<!DOCTYPE html><html lang='id'><head><meta charset='UTF-8'>"
            "<meta name='viewport' content='width=device-width,initial-scale=1.0'>"
            "<title>" + str(DEVICE_NAME) + "</title>"
            "<style>"
            "*{box-sizing:border-box;margin:0;padding:0}"
            "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0b1320;color:#f8fafc;padding:16px;line-height:1.5}"
            ".wrap{max-width:850px;margin:0 auto}"
            ".head{background:#1e293b;padding:20px;border-radius:14px;border:1px solid #334155;margin-bottom:16px}"
            "h1{font-size:22px;color:#38bdf8;margin-bottom:6px}"
            ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:14px;margin-bottom:16px}"
            ".card{background:#1e293b;padding:18px;border-radius:14px;border:1px solid #334155}"
            ".card h3{font-size:13px;color:#94a3b8;text-transform:uppercase;margin-bottom:10px}"
            ".val{font-size:24px;font-weight:700;color:#f8fafc;margin:4px 0}"
            ".sub{font-size:13px;color:#94a3b8}"
            ".badge{display:inline-block;padding:3px 9px;border-radius:999px;font-size:11px;font-weight:700}"
            ".bg-on{background:#065f46;color:#34d399}"
            ".bg-warn{background:#78350f;color:#fbbf24}"
            ".bg-danger{background:#881337;color:#f43f5e}"
            ".btn{display:inline-block;padding:8px 14px;border-radius:8px;font-weight:600;font-size:12px;text-decoration:none;margin-right:8px;margin-top:6px;background:#0284c7;color:white}"
            "</style></head><body>"
            "<div class='wrap'>"
            "<div class='head'>"
            "<h1>🌱 " + str(DEVICE_NAME) + " (" + str(DEVICE_ID) + ")</h1>"
            "<p class='sub'>Uptime: <strong>" + uptime_str + "</strong> &bull; IP: <strong style='color:#38bdf8'>" + ip_str + "</strong></p>"
            "<div style='margin-top:10px'>"
            "<a href='/api/status' class='btn' target='_blank'>JSON /api/status</a>"
            "<a href='/status' class='btn' target='_blank'>JSON PRD /status</a>"
            "<a href='/pump?action=toggle' class='btn' style='background:#059669'>Manual Pompa</a>"
            "<a href='/buzzer?action=toggle' class='btn' style='background:#dc2626'>Manual Buzzer</a>"
            "</div></div>"
            "<div class='grid'>"
            "<div class='card'>"
            "<h3>Pompa Air (Relay GPIO " + str(PIN_RELAY) + ")</h3>"
            "<div class='val' style='color:" + pump_color + "'>" + pump_label + "</div>"
            "<p class='sub'>Durasi: " + p_runtime + "s &bull; Cooldown: " + cooldown_str + "s</p>"
            + p_reasons_block +
            "</div>"
            "<div class='card'>"
            "<h3>Buzzer Alarm (GPIO " + str(PIN_BUZZER) + ")</h3>"
            "<div class='val' style='color:" + buzzer_color + "'>" + buzzer_label + "</div>"
            "<p class='sub'>Status Peringatan Suara</p>"
            + b_reasons_block +
            "</div>"
            "<div class='card'>"
            "<h3>Kelembapan Tanah (GPIO " + str(PIN_SOIL_MOISTURE) + ")</h3>"
            "<div class='val'>" + soil_pct_val + "%</div>"
            "<p class='sub'>ADC: " + soil_raw_val + " &bull; Status: <span class='badge " + soil_badge_cls + "'>" + soil_stat_val + "</span></p>"
            "</div>"
            "<div class='card'>"
            "<h3>DHT11 Suhu & Kelembapan (GPIO " + str(PIN_DHT11) + ")</h3>"
            "<div class='val'>" + dht_temp_val + " °C</div>"
            "<p class='sub'>Kelembapan Udara: <strong>" + dht_hum_val + "%RH</strong></p>"
            "<p class='sub'>Status: <span class='badge " + dht_badge_cls + "'>" + dht_stat + "</span></p>"
            "</div>"
            "<div class='card'>"
            "<h3>Thermocouple K-Type (MAX6675)</h3>"
            "<div class='val'>" + tc_temp_val + " °C</div>"
            "<p class='sub'>Frame Hex: " + tc_hex_val + " &bull; Status: <span class='badge " + tc_badge_cls + "'>" + tc_stat + "</span></p>"
            + tc_err_block +
            "</div>"
            "<div class='card'>"
            "<h3>MQ-2 Gas / Asap (GPIO " + str(PIN_MQ2) + ")</h3>"
            "<div class='val'>" + mq2_raw_val + " <span style='font-size:14px;color:#94a3b8'>ADC</span></div>"
            "<p class='sub'>Ambang Batas: " + str(MQ2_GAS_THRESHOLD) + " ADC</p>"
            "<p class='sub'>Status: <span class='badge " + mq2_badge_cls + "'>" + mq2_stat_val + "</span></p>"
            "</div>"
            "</div></div></body></html>"
        )
        return html

    def send_resp(self, client, code, content_type, body_str):
        body_bytes = body_str.encode("utf-8")
        msg = "OK" if code == 200 else ("Not Found" if code == 404 else "Error")
        header = (
            "HTTP/1.1 " + str(code) + " " + msg + "\r\n"
            "Content-Type: " + content_type + "\r\n"
            "Content-Length: " + str(len(body_bytes)) + "\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            "Connection: close\r\n"
            "\r\n"
        )
        client.sendall(header.encode("utf-8"))
        client.sendall(body_bytes)

    def handle_client(self, client):
        try:
            req_data = client.recv(1024)
            if not req_data:
                return

            req_str = req_data.decode("utf-8", "ignore")
            lines = req_str.split("\r\n")
            if not lines:
                return

            parts = lines[0].split()
            if len(parts) < 2:
                return

            method = parts[0]
            full_path = parts[1]
            path_split = full_path.split("?")
            path = path_split[0]
            query_str = path_split[1] if len(path_split) > 1 else ""

            # 1. Endpoint /api/status (Kompatibel penuh dengan Flutter App)
            if path == "/api/status":
                payload = self.build_full_status()
                self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))

            # 2. Endpoint /status (Format Persis PRD Seksi 9)
            elif path == "/status":
                payload = self.build_prd_format()
                self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))

            # 3. Endpoint /sensors
            elif path == "/sensors":
                payload = self.sensor_mgr.get_readings()
                self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))

            # 4. Endpoint /pump
            elif path == "/pump":
                if "action=on" in query_str:
                    self.pump_ctrl.turn_on("Manual HTTP API (action=on)")
                elif "action=off" in query_str:
                    self.pump_ctrl.turn_off("Manual HTTP API (action=off)")
                elif "action=toggle" in query_str:
                    if self.pump_ctrl.is_active:
                        self.pump_ctrl.turn_off("Manual HTTP API Toggle")
                    else:
                        self.pump_ctrl.turn_on("Manual HTTP API Toggle")
                payload = self.pump_ctrl.get_status()
                self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))

            # 5. Endpoint /buzzer
            elif path == "/buzzer":
                if "action=on" in query_str:
                    self.buzzer_ctrl.turn_on("Manual HTTP API (action=on)")
                elif "action=off" in query_str:
                    self.buzzer_ctrl.turn_off("Manual HTTP API (action=off)")
                elif "action=toggle" in query_str:
                    if self.buzzer_ctrl.is_active:
                        self.buzzer_ctrl.turn_off("Manual HTTP API Toggle")
                    else:
                        self.buzzer_ctrl.turn_on("Manual HTTP API Toggle")
                payload = self.buzzer_ctrl.get_status()
                self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))

            # 6. Endpoint /health
            elif path == "/health":
                payload = {
                    "status": "healthy",
                    "uptime": self.get_uptime_human(),
                    "free_ram_bytes": gc.mem_free(),
                    "wifi_connected": self.wifi_mgr.is_connected(),
                    "pump_active": self.pump_ctrl.is_active,
                    "buzzer_active": self.buzzer_ctrl.is_active
                }
                self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))

            # 7. Endpoint / (Dashboard Web HTML)
            elif path == "/":
                if "application/json" in req_str and "text/html" not in req_str:
                    payload = self.build_full_status()
                    self.send_resp(client, 200, "application/json; charset=utf-8", json.dumps(payload))
                else:
                    html_content = self.render_html()
                    self.send_resp(client, 200, "text/html; charset=utf-8", html_content)

            # 404 Not Found
            else:
                err_dict = {"error": "Endpoint tidak ditemukan", "path": path, "code": 404}
                self.send_resp(client, 404, "application/json; charset=utf-8", json.dumps(err_dict))

        except Exception as e:
            print("[API] Error handling: " + str(e))
        finally:
            gc.collect()

    def process_incoming(self):
        if not self.sock:
            return
        try:
            client, addr = self.sock.accept()
            client.settimeout(1.5)
            self.handle_client(client)
            client.close()
        except OSError:
            pass  # Timeout normal (non-blocking)
        except Exception as e:
            print("[API] Error accept: " + str(e))


# ==============================================================================
# 10. LOGIKA PENGAMBILAN KEPUTUSAN OTOMASI (PRD SEKSI 7)
# ==============================================================================
def evaluate_automation(sensor_data, pump_ctrl, buzzer_ctrl):
    """
    Logika Otomatisasi PRD DiHutan v2.2 (FR-05, FR-06, FR-07):
    -------------------------------------------------------------------------
    Kondisi                        | Pompa | Buzzer
    -------------------------------------------------------------------------
    Semua sensor normal            | OFF   | OFF
    Tanah kering (>= 2000 ADC)    | ON    | OFF  <- tanah kering TIDAK nyalakan buzzer
    Gas tinggi (>= 2500 ADC)      | OFF   | ON   <- gas tinggi TIDAK nyalakan pompa
    Thermocouple >= 50 C           | ON    | ON   <- suhu tinggi nyalakan KEDUANYA
    Gas tinggi + Tanah kering      | ON    | ON
    Thermocouple + Gas + Tanah     | ON    | ON
    -------------------------------------------------------------------------
    Rumus Gabungan Output (FR-06 & FR-07 PRD v2.2):
    - Buzzer : (tc_temp >= THERMO_FIRE_THRESHOLD) OR (gas_raw >= MQ2_GAS_THRESHOLD)
    - Pompa  : (tc_temp >= THERMO_FIRE_THRESHOLD) OR (soil kering)

    CATATAN: DHT11 hanya informasi suhu udara, TIDAK memicu aktuator.
    Fail-Safe: Jika MAX6675 error/terputus, pemicu suhu dinonaktifkan secara aman.
    """
    soil   = sensor_data.get("soil_moisture", {})
    mq2    = sensor_data.get("mq2", {})
    thermo = sensor_data.get("thermocouple", {})

    pump_reasons   = []
    buzzer_reasons = []
    is_fire_detected = False

    # 1. Evaluasi Thermocouple MAX6675
    # Probe normal   : tc_temp >= 50 C          -> Pompa ON + Buzzer ON
    # Probe terbalik : tc_temp <= 10 C           -> Pompa ON + Buzzer ON
    # Status ERROR   : terputus/open-circuit     -> Pompa ON + Buzzer ON (anggap kondisi berbahaya)
    tc_status = thermo.get("status", "error")
    tc_temp   = thermo.get("temperature")
    tc_valid  = (tc_status not in ("error",)) and (tc_temp is not None)

    if not tc_valid:
        # Sensor error / probe terputus -> aktifkan pompa + buzzer sebagai tindakan pengamanan
        is_fire_detected = True
        tc_err_detail = thermo.get("error", "Sensor error")
        msg_err = "THERMOCOUPLE ERROR/PUTUS (" + str(tc_err_detail) + ") -> POMPA + BUZZER ON (Fail-Safe)"
        pump_reasons.append(msg_err)
        buzzer_reasons.append(msg_err)
    else:
        if tc_temp >= THERMO_FIRE_THRESHOLD or tc_temp <= THERMO_FIRE_REVERSED or thermo.get("fire_detected", False):
            is_fire_detected = True
            if tc_temp <= THERMO_FIRE_REVERSED:
                msg_fire = "PROBE TERBALIK PANAS (" + str(tc_temp) + "C <= " + str(THERMO_FIRE_REVERSED) + "C) -> POMPA + BUZZER ON"
            else:
                msg_fire = "THERMOCOUPLE PANAS (" + str(tc_temp) + "C >= " + str(THERMO_FIRE_THRESHOLD) + "C) -> POMPA + BUZZER ON"
            pump_reasons.append(msg_fire)
            buzzer_reasons.append(msg_fire)
        elif (pump_ctrl.is_active or buzzer_ctrl.is_active) and tc_temp > THERMO_TEMP_SAFE_THRESHOLD:
            # Hysteresis: tetap aktif sampai suhu turun ke bawah batas aman
            msg_tc_warm = "Thermocouple masih panas (" + str(tc_temp) + "C > " + str(THERMO_TEMP_SAFE_THRESHOLD) + "C)"
            pump_reasons.append(msg_tc_warm)
            buzzer_reasons.append(msg_tc_warm)

    # 2. Evaluasi Gas MQ-2 (PRD v2.2 FR-06: Gas tinggi -> Buzzer ON SAJA, Pompa TIDAK)
    mq2_raw = mq2.get("raw")
    mq2_valid = mq2.get("status") != "error" and mq2_raw is not None
    if mq2_valid and mq2_raw >= MQ2_GAS_THRESHOLD:
        buzzer_reasons.append("Gas tinggi (" + str(mq2_raw) + " ADC >= " + str(MQ2_GAS_THRESHOLD) + ")")

    # 3. Evaluasi Kelembapan Tanah (PRD v2.2 FR-07: Tanah kering -> Pompa ON SAJA, Buzzer TIDAK)
    soil_pct = soil.get("percentage")
    soil_valid = soil.get("status") != "error" and soil_pct is not None
    if soil_valid:
        if pump_ctrl.is_active and not is_fire_detected:
            # Hysteresis: pompa tetap menyala sampai tanah cukup basah (target 65%)
            if soil_pct < SOIL_TARGET_WET_PERCENT:
                pump_reasons.append("Tanah belum basah (" + str(soil_pct) + "% < " + str(SOIL_TARGET_WET_PERCENT) + "%)")
        else:
            if soil_pct <= SOIL_TRIGGER_DRY_PERCENT:
                pump_reasons.append("Tanah kering (" + str(soil_pct) + "%) -> Penyiraman otomatis")

    # 4. Pengaman Timeout Pompa (FR-10: pompa tidak menyala terus menerus)
    if pump_ctrl.is_active and pump_ctrl.get_runtime_seconds() >= PUMP_MAX_RUNTIME_SEC:
        pump_ctrl.turn_off("Batas waktu maksimal " + str(PUMP_MAX_RUNTIME_SEC) + "s tercapai")
        pump_reasons = []

    # 5. Pengaman Cooldown Pompa (Kecuali kondisi darurat thermocouple panas!)
    if not pump_ctrl.is_active and pump_ctrl.get_cooldown_remaining_sec() > 0:
        if not is_fire_detected:
            pump_reasons = []

    # 6. Eksekusi Pompa
    if len(pump_reasons) > 0:
        pump_ctrl.active_reasons = pump_reasons
        if not pump_ctrl.is_active:
            pump_ctrl.turn_on(" + ".join(pump_reasons))
    else:
        if pump_ctrl.is_active:
            pump_ctrl.turn_off("Kondisi lingkungan normal")

    # 7. Eksekusi Buzzer (sirine darurat jika thermocouple panas, nada biasa jika gas)
    if len(buzzer_reasons) > 0:
        buzzer_ctrl.active_reasons = buzzer_reasons
        buzzer_ctrl.turn_on(" + ".join(buzzer_reasons), emergency=is_fire_detected)
    else:
        if buzzer_ctrl.is_active:
            buzzer_ctrl.turn_off("Kondisi lingkungan kembali aman")


# ==============================================================================
# 11. FORMAT SERIAL MONITOR (PRD SEKSI 12)
# ==============================================================================
def print_serial_monitor(sensor_data, pump_ctrl, buzzer_ctrl):
    """Mencetak status pemantauan rapi sesuai format PRD Seksi 12."""
    soil   = sensor_data.get("soil_moisture", {})
    dht_s  = sensor_data.get("dht11", {})
    mq2    = sensor_data.get("mq2", {})
    thermo = sensor_data.get("thermocouple", {})

    temp_air_val = dht_s.get("temperature")
    temp_air_str = (str(temp_air_val) + " C") if temp_air_val is not None else "ERROR"

    hum_air_val  = dht_s.get("humidity")
    hum_air_str  = (str(hum_air_val) + " %") if hum_air_val is not None else "ERROR"

    tc_val       = thermo.get("temperature")
    tc_str       = (str(tc_val) + " C") if tc_val is not None else "ERROR"

    mq2_val_str  = str(mq2.get("raw", "-"))
    soil_val_str = str(soil.get("raw", "-"))

    soil_pct_val = soil.get("percentage")
    soil_pct_str = (str(soil_pct_val) + " %") if soil_pct_val is not None else "ERROR"

    gas_status   = str(mq2.get("status", "NORMAL"))
    soil_status  = str(soil.get("status", "NORMAL"))
    pump_status  = "ON" if pump_ctrl.is_active else "OFF"
    buzzer_status = "ON" if buzzer_ctrl.is_active else "OFF"

    sys_status = "NORMAL"
    if mq2.get("gas_detected") or pump_ctrl.is_active or buzzer_ctrl.is_active:
        sys_status = "ALERT / ACTIVE"

    print("================================")
    print("        IOT MONITORING          ")
    print("================================")
    print("Air Temperature : " + temp_air_str)
    print("Air Humidity    : " + hum_air_str)
    print("Thermocouple    : " + tc_str)
    print("MQ-2 Value      : " + mq2_val_str)
    print("Soil Value      : " + soil_val_str)
    print("Soil Moisture   : " + soil_pct_str)
    print("")
    print("Gas Status      : " + gas_status)
    print("Soil Status     : " + soil_status)
    print("Pump Status     : " + pump_status)
    print("Buzzer Status   : " + buzzer_status)
    print("System Status   : " + sys_status)
    print("================================\n")


# ==============================================================================
# 12. FUNGSI UTAMA (MAIN LOOP)
# ==============================================================================
def main():
    boot_ticks = time.ticks_ms()

    print("\n" + "=" * 60)
    print("   SISTEM MONITORING & OTOMASI BERBASIS IoT ESP32 (MONU)   ")
    print("=" * 60)
    print(" [KONFIGURASI GPIO PRD SEKSI 4]")
    print("  - MAX6675 SCK     : GPIO " + str(PIN_MAX6675_SCK))
    print("  - MAX6675 SO      : GPIO " + str(PIN_MAX6675_SO))
    print("  - MAX6675 CS      : GPIO " + str(PIN_MAX6675_CS))
    print("  - MQ-2 AO         : GPIO " + str(PIN_MQ2))
    print("  - DHT11 DATA      : GPIO " + str(PIN_DHT11))
    print("  - Soil Moisture AO: GPIO " + str(PIN_SOIL_MOISTURE))
    relay_mode_str = "Active-LOW" if RELAY_ACTIVE_LOW else "Active-HIGH"
    print("  - Relay Pompa IN  : GPIO " + str(PIN_RELAY) + " (" + relay_mode_str + ")")
    print("  - Buzzer IO       : GPIO " + str(PIN_BUZZER))
    print("=" * 60 + "\n")

    # Bebaskan memori heap terlebih dahulu sebelum mengalokasikan driver Wi-Fi ESP32
    gc.collect()

    # 1. Hubungkan Wi-Fi lebih dulu agar stack Wi-Fi mendapat blok RAM internal utuh
    print("[1/5] Menghubungkan ke Wi-Fi '" + str(WIFI_SSID) + "'...")
    wifi_mgr = WiFiManager(ssid=WIFI_SSID, password=WIFI_PASSWORD)
    wifi_mgr.connect(timeout_s=WIFI_TIMEOUT_SEC)

    # 2. Inisialisasi Aktuator Pompa & Buzzer
    print("[2/5] Inisialisasi Aktuator (Pompa & Buzzer)...")
    pump_ctrl = PumpController(pin_num=PIN_RELAY, active_low=RELAY_ACTIVE_LOW)
    buzzer_ctrl = BuzzerController(pin_num=PIN_BUZZER, active_high=BUZZER_ACTIVE_HIGH, use_pwm=BUZZER_USE_PWM)

    # Uji coba bunyi bip singkat penanda sistem aktif
    buzzer_ctrl.beep(80)

    # 3. Inisialisasi Seluruh Sensor
    print("[3/5] Inisialisasi Sensor...")
    sensor_mgr = SensorManager(boot_ticks=boot_ticks)

    # 4. Jalankan HTTP REST API Server
    print("[4/5] Memulai HTTP Server port 80...")
    http_server = HttpServer(
        sensor_mgr=sensor_mgr,
        pump_ctrl=pump_ctrl,
        buzzer_ctrl=buzzer_ctrl,
        wifi_mgr=wifi_mgr,
        boot_ticks=boot_ticks,
        port=SERVER_PORT
    )
    http_server.start()

    ip = wifi_mgr.get_ip()
    print("[5/5] Inisialisasi Selesai.")
    print("==================================================")
    print(" Web Dashboard : http://" + str(ip) + "/")
    print(" REST API JSON : http://" + str(ip) + "/api/status")
    print(" PRD JSON      : http://" + str(ip) + "/status")
    print("==================================================\n")

    last_sensor_ticks = 0
    last_log_ticks = 0

    try:
        while True:
            now = time.ticks_ms()

            # Modulasi frekuensi sirine buzzer (suara ekstra nyaring & menusuk)
            buzzer_ctrl.update()

            # A. Layani request HTTP secara non-blocking
            http_server.process_incoming()

            # B. Cek status Wi-Fi & reconnect otomatis di latar belakang
            wifi_mgr.check_and_reconnect()

            # C. Pembacaan Sensor & Evaluasi Logika Otomasi (Tiap 1 detik)
            if time.ticks_diff(now, last_sensor_ticks) >= SENSOR_READ_INTERVAL_MS:
                last_sensor_ticks = now

                # Baca semua sensor
                data = sensor_mgr.read_all()

                # Jalankan tabel logika otomasi (Pompa & Buzzer)
                evaluate_automation(data, pump_ctrl, buzzer_ctrl)

            # D. Cetak Format Serial Monitor (Tiap 3 detik)
            if time.ticks_diff(now, last_log_ticks) >= SERIAL_LOG_INTERVAL_MS:
                last_log_ticks = now
                print_serial_monitor(sensor_mgr.get_readings(), pump_ctrl, buzzer_ctrl)
                gc.collect()

            # Delay kooperatif 10ms
            time.sleep_ms(10)

    except KeyboardInterrupt:
        print("\n[System] Program dihentikan pengguna.")
    finally:
        print("[System] Mematikan seluruh aktuator (Pompa & Buzzer)...")
        pump_ctrl.turn_off("Shutdown Sistem")
        buzzer_ctrl.turn_off("Shutdown Sistem")
        print("[System] Selesai.")

if __name__ == "__main__":
    main()
