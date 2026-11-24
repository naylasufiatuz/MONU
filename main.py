# ==============================================================================
# SISTEM IoT MONITORING DAN KONTROL PERANGKAT (MONU) - ESP32
# Program Utama: main.py
# Bahasa: MicroPython
#
# Fitur Utama:
# 1. Koneksi Wi-Fi otomatis menggunakan DHCP (tanpa IP statis).
# 2. Mekanisme reconnect otomatis tanpa me-restart ESP32.
# 3. HTTP Web Server pada port 80 (Non-blocking).
# 4. Endpoint '/' untuk dashboard informasi perangkat via browser.
# 5. Endpoint '/api/status' untuk komunikasi JSON dengan aplikasi client.
# 6. Struktur pembacaan sensor lengkap (Soil Moisture, DHT11, MQ-2, MAX6675, Relay)
#    tanpa data palsu (menampilkan status 'belum_tersedia' jika sensor belum terpasang).
# ==============================================================================

import network
import usocket as socket
import ujson as json
import utime as time
import machine
import dht
import gc

# ==============================================================================
# 1. PENGATURAN WI-FI & IDENTITAS PERANGKAT
# ==============================================================================
# Silakan ubah SSID dan PASSWORD sesuai jaringan Wi-Fi / Hotspot Anda.
WIFI_SSID     = "NAMA_WIFI_ANDA"
WIFI_PASSWORD = "PASSWORD_WIFI_ANDA"

# Identitas perangkat (sesuai konfigurasi aplikasi: monu-node-1)
DEVICE_ID     = "monu-node-1"
DEVICE_NAME   = "ESP32 MONU Node"
SERVER_PORT   = 80

# Interval pemeriksaan koneksi Wi-Fi (dalam milidetik: 10 detik)
WIFI_CHECK_INTERVAL_MS = 10000

# ==============================================================================
# 2. DEFINISI PIN GPIO (SESUAI SPESIFIKASI SISTEM)
# ==============================================================================
# PERINGATAN: Jangan mengubah nomor GPIO tanpa alasan teknis yang jelas.
PIN_SOIL_MOISTURE = 35   # ADC Input Only (Sensor Kelembapan Tanah)
PIN_DHT11         = 33   # Digital Input/Output (Suhu & Kelembapan Udara)
PIN_MQ2           = 34   # ADC Input Only (Sensor Gas & Asap)
PIN_MAX6675_SCK   = 18   # SPI Clock (Thermocouple K-Type)
PIN_MAX6675_CS    = 21   # SPI Chip Select (Thermocouple K-Type)
PIN_MAX6675_SO    = 23   # SPI MISO / Data Out (Thermocouple K-Type)
PIN_RELAY         = 19   # Digital Output (Relay Pompa Air)

# ==============================================================================
# 3. FLAG SENSOR FISIK
# ==============================================================================
# Pin analog (ADC34 & ADC35) yang tidak terhubung ke sensor fisik akan membaca
# tegangan mengambang (floating noise). Agar sistem TIDAK menghasilkan data palsu,
# ubah nilai di bawah menjadi True HANYA ketika modul sensor fisik sudah dipasang.
SOIL_SENSOR_ATTACHED = False
MQ2_SENSOR_ATTACHED  = False

# ==============================================================================
# 4. VARIABEL GLOBAL & HARDWARE INSTANCES
# ==============================================================================
wlan = None
boot_ticks = time.ticks_ms()
last_wifi_check_ticks = 0
relay_state = 0  # 0 = OFF (Pompa Mati), 1 = ON (Pompa Hidup)

# Objek modul hardware
adc_soil = None
adc_mq2  = None
dht_sensor = None
pin_max_sck = None
pin_max_cs  = None
pin_max_so  = None
pin_relay   = None


# ==============================================================================
# 5. INISIALISASI HARDWARE
# ==============================================================================
def init_hardware():
    """
    Inisialisasi GPIO untuk seluruh sensor dan aktuator relay.
    Menghindari kegagalan fatal jika pin belum terhubung secara fisik.
    """
    global adc_soil, adc_mq2, dht_sensor
    global pin_max_sck, pin_max_cs, pin_max_so, pin_relay

    print("[Hardware] Menginisialisasi pin GPIO...")

    # Inisialisasi Relay (GPIO 19)
    try:
        pin_relay = machine.Pin(PIN_RELAY, machine.Pin.OUT)
        pin_relay.value(0)  # Default: Pompa mati
        print(f"  - Relay Pompa     : GPIO {PIN_RELAY} (Output, Default OFF)")
    except Exception as e:
        print(f"  - Relay Pompa     : Gagal ({e})")

    # Inisialisasi ADC Soil Moisture (GPIO 35)
    try:
        adc_soil = machine.ADC(machine.Pin(PIN_SOIL_MOISTURE))
        adc_soil.atten(machine.ADC.ATTN_11DB)  # Rentang 0 - 3.3V
        print(f"  - Soil Moisture   : GPIO {PIN_SOIL_MOISTURE} (ADC Input)")
    except Exception as e:
        print(f"  - Soil Moisture   : Gagal ({e})")

    # Inisialisasi ADC MQ-2 (GPIO 34)
    try:
        adc_mq2 = machine.ADC(machine.Pin(PIN_MQ2))
        adc_mq2.atten(machine.ADC.ATTN_11DB)  # Rentang 0 - 3.3V
        print(f"  - MQ-2 Gas/Asap   : GPIO {PIN_MQ2} (ADC Input)")
    except Exception as e:
        print(f"  - MQ-2 Gas/Asap   : Gagal ({e})")

    # Inisialisasi DHT11 (GPIO 33)
    try:
        dht_sensor = dht.DHT11(machine.Pin(PIN_DHT11))
        print(f"  - DHT11           : GPIO {PIN_DHT11} (Digital 1-Wire)")
    except Exception as e:
        print(f"  - DHT11           : Gagal ({e})")

    # Inisialisasi SPI MAX6675 Thermocouple (SCK=18, CS=21, SO=23)
    try:
        pin_max_sck = machine.Pin(PIN_MAX6675_SCK, machine.Pin.OUT)
        pin_max_cs  = machine.Pin(PIN_MAX6675_CS, machine.Pin.OUT)
        pin_max_so  = machine.Pin(PIN_MAX6675_SO, machine.Pin.IN)
        pin_max_cs.value(1)   # CS idle high
        pin_max_sck.value(0)  # SCK idle low
        print(f"  - MAX6675 Thermo  : SCK={PIN_MAX6675_SCK}, CS={PIN_MAX6675_CS}, SO={PIN_MAX6675_SO}")
    except Exception as e:
        print(f"  - MAX6675 Thermo  : Gagal ({e})")

    print("[Hardware] Inisialisasi pin selesai.\n")


# ==============================================================================
# 6. FUNGSI PEMBACAAN SENSOR & KONTROL RELAY
# ==============================================================================
def read_soil_moisture():
    """
    Membaca nilai sensor kelembapan tanah (ADC GPIO 35).
    Jika belum dipasang (SOIL_SENSOR_ATTACHED == False), mengembalikan status belum tersedia.
    """
    if not SOIL_SENSOR_ATTACHED or adc_soil is None:
        return {
            "name": "Soil Moisture",
            "gpio": PIN_SOIL_MOISTURE,
            "status": "belum_tersedia",
            "raw_adc": None,
            "unit": "ADC"
        }
    try:
        val = adc_soil.read()
        return {
            "name": "Soil Moisture",
            "gpio": PIN_SOIL_MOISTURE,
            "status": "tersedia",
            "raw_adc": val,
            "unit": "ADC"
        }
    except Exception as e:
        return {
            "name": "Soil Moisture",
            "gpio": PIN_SOIL_MOISTURE,
            "status": "belum_tersedia",
            "raw_adc": None,
            "error": str(e)
        }


def read_dht11():
    """
    Membaca suhu dan kelembapan udara dari sensor DHT11 (GPIO 33).
    Jika sensor tidak merespons (belum terhubung fisik), mengembalikan belum tersedia.
    """
    if dht_sensor is None:
        return {
            "name": "DHT11",
            "gpio": PIN_DHT11,
            "status": "belum_tersedia",
            "temperature": None,
            "humidity": None
        }
    try:
        dht_sensor.measure()
        temp = dht_sensor.temperature()
        hum  = dht_sensor.humidity()
        return {
            "name": "DHT11",
            "gpio": PIN_DHT11,
            "status": "tersedia",
            "temperature": temp,
            "humidity": hum,
            "temp_unit": "°C",
            "humidity_unit": "%RH"
        }
    except OSError:
        # OSError terjadi saat DHT11 tidak dicolokkan ke pin atau timeout komunikasi
        return {
            "name": "DHT11",
            "gpio": PIN_DHT11,
            "status": "belum_tersedia",
            "temperature": None,
            "humidity": None,
            "temp_unit": "°C",
            "humidity_unit": "%RH"
        }


def read_mq2():
    """
    Membaca nilai analog sensor MQ-2 (ADC GPIO 34).
    Jika belum dipasang (MQ2_SENSOR_ATTACHED == False), mengembalikan status belum tersedia.
    """
    if not MQ2_SENSOR_ATTACHED or adc_mq2 is None:
        return {
            "name": "MQ-2 Gas / Asap",
            "gpio": PIN_MQ2,
            "status": "belum_tersedia",
            "raw_adc": None,
            "unit": "ADC"
        }
    try:
        val = adc_mq2.read()
        return {
            "name": "MQ-2 Gas / Asap",
            "gpio": PIN_MQ2,
            "status": "tersedia",
            "raw_adc": val,
            "unit": "ADC"
        }
    except Exception as e:
        return {
            "name": "MQ-2 Gas / Asap",
            "gpio": PIN_MQ2,
            "status": "belum_tersedia",
            "raw_adc": None,
            "error": str(e)
        }


def read_thermocouple():
    """
    Membaca data suhu dari modul thermocouple MAX6675 via SPI bitbang.
    Format data 16-bit: D14..D3 (suhu), D2 (status open-circuit thermocouple).
    """
    if pin_max_cs is None or pin_max_sck is None or pin_max_so is None:
        return {
            "name": "Thermocouple MAX6675",
            "gpio": {"sck": PIN_MAX6675_SCK, "cs": PIN_MAX6675_CS, "so": PIN_MAX6675_SO},
            "status": "belum_tersedia",
            "temperature": None,
            "unit": "°C"
        }
    try:
        pin_max_cs.value(0)
        time.sleep_us(10)
        data = 0
        for _ in range(16):
            pin_max_sck.value(1)
            time.sleep_us(5)
            data = (data << 1) | pin_max_so.value()
            pin_max_sck.value(0)
            time.sleep_us(5)
        pin_max_cs.value(1)

        # Jika data bernilai 0, 0xFFFF (semua 1), atau bit D2 bernilai 1 (kabel lepas/tidak terpasang)
        if data == 0 or data == 0xFFFF or (data & 0x0004):
            return {
                "name": "Thermocouple MAX6675",
                "gpio": {"sck": PIN_MAX6675_SCK, "cs": PIN_MAX6675_CS, "so": PIN_MAX6675_SO},
                "status": "belum_tersedia",
                "temperature": None,
                "unit": "°C"
            }

        # Mengambil bit 3-14 (12-bit) dengan resolusi 0.25 °C
        temp_c = ((data >> 3) & 0x0FFF) * 0.25
        return {
            "name": "Thermocouple MAX6675",
            "gpio": {"sck": PIN_MAX6675_SCK, "cs": PIN_MAX6675_CS, "so": PIN_MAX6675_SO},
            "status": "tersedia",
            "temperature": temp_c,
            "unit": "°C"
        }
    except Exception as e:
        return {
            "name": "Thermocouple MAX6675",
            "gpio": {"sck": PIN_MAX6675_SCK, "cs": PIN_MAX6675_CS, "so": PIN_MAX6675_SO},
            "status": "belum_tersedia",
            "temperature": None,
            "error": str(e)
        }


def set_relay(state):
    """
    Mengontrol status relay pompa air (0 = MATI, 1 = HIDUP).
    """
    global relay_state, pin_relay
    relay_state = 1 if state else 0
    if pin_relay:
        pin_relay.value(relay_state)
        print(f"[Relay] Pompa air diatur ke: {'HIDUP (ON)' if relay_state else 'MATI (OFF)'}")
        return True
    return False


def get_relay_info():
    """Mengembalikan status terkini aktuator relay."""
    return {
        "name": "Pompa Air (Relay)",
        "gpio": PIN_RELAY,
        "status": "tersedia",
        "state": relay_state,
        "state_label": "ON" if relay_state == 1 else "OFF"
    }


def get_uptime_seconds():
    """Menghitung waktu aktif ESP32 dalam detik sejak booting."""
    now = time.ticks_ms()
    diff = time.ticks_diff(now, boot_ticks)
    return diff // 1000


def get_uptime_human():
    """Mengubah detik uptime menjadi format 'Xj Ym Zd'."""
    sec = get_uptime_seconds()
    hours = sec // 3600
    minutes = (sec % 3600) // 60
    seconds = sec % 60
    return f"{hours}j {minutes}m {seconds}d"


# ==============================================================================
# 7. MANAJEMEN KONEKSI WI-FI (DHCP & RECONNECT)
# ==============================================================================
def connect_wifi(timeout_s=15):
    """
    Menghubungkan ESP32 ke jaringan Wi-Fi secara otomatis melalui DHCP.
    Tidak menggunakan IP statis dan tidak me-restart ESP32 jika gagal.
    """
    global wlan
    if wlan is None:
        wlan = network.WLAN(network.STA_IF)

    if not wlan.active():
        wlan.active(True)

    # Set DHCP hostname agar mudah dikenali router
    try:
        wlan.config(dhcp_hostname="monu-esp32")
    except:
        pass

    if wlan.isconnected():
        return True

    print(f"[Wi-Fi] Menghubungkan ke SSID: '{WIFI_SSID}'...")
    wlan.connect(WIFI_SSID, WIFI_PASSWORD)

    start_time = time.time()
    dots = 0
    while not wlan.isconnected():
        if time.time() - start_time > timeout_s:
            print("\n[Wi-Fi] Gagal terhubung (Waktu habis / Timeout).")
            print("[Wi-Fi] ESP32 tetap berjalan dan akan mencoba menyambung di latar belakang.")
            return False

        time.sleep_ms(400)
        print(".", end="")
        dots += 1
        if dots % 25 == 0:
            print()

    # Berhasil terhubung
    ip_addr, subnet, gateway, dns = wlan.ifconfig()
    print("\n")
    print("==================================================")
    print("           ESP32 BERHASIL TERHUBUNG WI-FI         ")
    print("==================================================")
    print(f" Status Wi-Fi : Terhubung (Connected)")
    print(f" SSID         : {WIFI_SSID}")
    print(f" IP Address   : {ip_addr}")
    print(f" Subnet Mask  : {subnet}")
    print(f" Gateway      : {gateway}")
    print(f" DNS Server   : {dns}")
    print("==================================================\n")
    return True


def get_ip_address():
    """
    Mengambil IP Address ESP32 dari konfigurasi DHCP.
    Mengembalikan string IP Address atau '0.0.0.0' jika belum terhubung.
    """
    global wlan
    if wlan and wlan.isconnected():
        return wlan.ifconfig()[0]
    return "0.0.0.0"


def check_wifi_connection():
    """
    Memeriksa koneksi Wi-Fi secara periodik.
    Jika koneksi terputus, mencoba menghubungkan kembali secara otomatis tanpa reboot.
    """
    global last_wifi_check_ticks, wlan
    now = time.ticks_ms()
    if time.ticks_diff(now, last_wifi_check_ticks) < WIFI_CHECK_INTERVAL_MS:
        return (wlan is not None and wlan.isconnected())

    last_wifi_check_ticks = now

    if wlan is None or not wlan.isconnected():
        print("[Wi-Fi] Peringatan: Koneksi terputus! Mencoba menghubungkan kembali...")
        try:
            if wlan is None:
                wlan = network.WLAN(network.STA_IF)
            if not wlan.active():
                wlan.active(True)

            wlan.connect(WIFI_SSID, WIFI_PASSWORD)

            # Beri kesempatan singkat untuk negosiasi IP
            attempts = 0
            while not wlan.isconnected() and attempts < 6:
                time.sleep_ms(300)
                attempts += 1

            if wlan.isconnected():
                print(f"[Wi-Fi] Reconnect Berhasil! IP Address baru: {wlan.ifconfig()[0]}")
                return True
            else:
                print("[Wi-Fi] Belum terhubung kembali. Akan dicoba lagi pada siklus berikutnya.")
                return False
        except Exception as e:
            print(f"[Wi-Fi] Error saat reconnect: {e}")
            return False

    return True


# ==============================================================================
# 8. INFORMASI STATUS PERANGKAT
# ==============================================================================
def get_device_status():
    """
    Mengumpulkan seluruh status perangkat, jaringan, sensor, dan aktuator
    dalam struktur kamus (dict) yang siap di-serialize menjadi JSON.
    """
    global wlan
    is_connected = (wlan is not None and wlan.isconnected())
    ip_addr, subnet, gateway, dns = ("0.0.0.0", "0.0.0.0", "0.0.0.0", "0.0.0.0")
    mac_str = "00:00:00:00:00:00"
    rssi_val = None

    if is_connected:
        ip_addr, subnet, gateway, dns = wlan.ifconfig()
        try:
            mac_bytes = wlan.config("mac")
            mac_str = ":".join(f"{b:02X}" for b in mac_bytes)
        except:
            pass
        try:
            rssi_val = wlan.status("rssi")
        except:
            pass

    # Ambil status sensor dan relay
    soil_data   = read_soil_moisture()
    dht_data    = read_dht11()
    mq2_data    = read_mq2()
    thermo_data = read_thermocouple()
    relay_data  = get_relay_info()

    return {
        "device_id": DEVICE_ID,
        "device_name": DEVICE_NAME,
        "status": "online" if is_connected else "disconnected",
        "device_status": "online" if is_connected else "disconnected",
        "wifi_connected": is_connected,
        "ip_address": ip_addr,
        "timestamp_uptime": get_uptime_seconds(),
        "uptime_human": get_uptime_human(),
        "wifi": {
            "connected": is_connected,
            "status": "terhubung" if is_connected else "terputus",
            "ssid": WIFI_SSID,
            "ip_address": ip_addr,
            "subnet_mask": subnet,
            "gateway": gateway,
            "dns": dns,
            "mac_address": mac_str,
            "rssi": rssi_val
        },
        "sensors": {
            "soil_moisture": soil_data,
            "dht11": dht_data,
            "mq2": mq2_data,
            "thermocouple": thermo_data
        },
        "actuators": {
            "relay": relay_data
        }
    }


# ==============================================================================
# 9. HTTP RESPONSE GENERATOR (HTML & JSON)
# ==============================================================================
def render_dashboard_html():
    """
    Menghasilkan tampilan dashboard web HTML sederhana, ringan, dan responsif
    untuk diakses via browser pada endpoint '/'.
    """
    status = get_device_status()
    wifi = status["wifi"]
    sensors = status["sensors"]
    relay = status["actuators"]["relay"]

    html = f"""<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{DEVICE_NAME} - Monitoring</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 20px; }}
        .container {{ max-width: 800px; margin: 0 auto; }}
        .header {{ background: #1e293b; padding: 20px; border-radius: 12px; margin-bottom: 20px; border: 1px solid #334155; }}
        h1 {{ font-size: 22px; color: #38bdf8; margin-bottom: 6px; }}
        .badge {{ display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; text-transform: uppercase; }}
        .badge-online {{ background: #065f46; color: #34d399; }}
        .badge-warn {{ background: #78350f; color: #fde68a; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 16px; margin-bottom: 20px; }}
        .card {{ background: #1e293b; padding: 18px; border-radius: 12px; border: 1px solid #334155; }}
        .card h3 {{ font-size: 14px; color: #94a3b8; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px; }}
        .card p {{ font-size: 14px; margin-bottom: 6px; }}
        .val {{ font-size: 18px; font-weight: 700; color: #f8fafc; }}
        .status-unavail {{ color: #94a3b8; font-style: italic; }}
        .btn {{ display: inline-block; background: #0284c7; color: white; padding: 10px 18px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 14px; margin-top: 10px; }}
        .btn:hover {{ background: #0369a1; }}
        footer {{ text-align: center; font-size: 12px; color: #64748b; margin-top: 24px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌱 {status['device_name']} ({status['device_id']})</h1>
            <p>Status: <span class="badge badge-online">{status['status']}</span> | Uptime: <strong>{status['uptime_human']}</strong></p>
            <p style="margin-top: 10px;">
                <a href="/api/status" class="btn">Buka JSON API (/api/status)</a>
            </p>
        </div>

        <div class="grid">
            <div class="card">
                <h3>Informasi Jaringan</h3>
                <p>SSID: <strong>{wifi['ssid']}</strong></p>
                <p>IP: <span class="val" style="color: #38bdf8;">{wifi['ip_address']}</span></p>
                <p>Subnet: {wifi['subnet_mask']}</p>
                <p>Gateway: {wifi['gateway']}</p>
            </div>

            <div class="card">
                <h3>Relay & Pompa (GPIO {relay['gpio']})</h3>
                <p>Status Pompa: <span class="val" style="color: {'#34d399' if relay['state'] else '#94a3b8'};">{relay['state_label']}</span></p>
                <p>Aktuator siap dihubungkan ke driver pompa.</p>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <h3>Soil Moisture (GPIO {sensors['soil_moisture']['gpio']})</h3>
                <p>Status: <span class="status-unavail">{sensors['soil_moisture']['status']}</span></p>
                <p>Nilai: <span class="val">{sensors['soil_moisture']['raw_adc'] or '-'}</span></p>
            </div>

            <div class="card">
                <h3>DHT11 (GPIO {sensors['dht11']['gpio']})</h3>
                <p>Status: <span class="status-unavail">{sensors['dht11']['status']}</span></p>
                <p>Suhu: <span class="val">{sensors['dht11']['temperature'] or '-'} °C</span></p>
                <p>Kelembapan: <span class="val">{sensors['dht11']['humidity'] or '-'} %RH</span></p>
            </div>

            <div class="card">
                <h3>MQ-2 Gas (GPIO {sensors['mq2']['gpio']})</h3>
                <p>Status: <span class="status-unavail">{sensors['mq2']['status']}</span></p>
                <p>Nilai: <span class="val">{sensors['mq2']['raw_adc'] or '-'}</span></p>
            </div>

            <div class="card">
                <h3>Thermocouple (MAX6675)</h3>
                <p>Status: <span class="status-unavail">{sensors['thermocouple']['status']}</span></p>
                <p>Suhu: <span class="val">{sensors['thermocouple']['temperature'] or '-'} °C</span></p>
            </div>
        </div>

        <footer>
            ESP32 IoT Node &bull; MicroPython &bull; Port 80 Web Server
        </footer>
    </div>
</body>
</html>"""
    return html


def send_response(client_socket, status_code, content_type, body_bytes):
    """Mengirim header dan isi respons HTTP secara aman ke client."""
    status_msg = "OK" if status_code == 200 else ("Not Found" if status_code == 404 else "Internal Error")
    header = (
        f"HTTP/1.1 {status_code} {status_msg}\r\n"
        f"Content-Type: {content_type}\r\n"
        f"Content-Length: {len(body_bytes)}\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Access-Control-Allow-Methods: GET, OPTIONS\r\n"
        "Connection: close\r\n"
        "\r\n"
    )
    client_socket.sendall(header.encode("utf-8"))
    client_socket.sendall(body_bytes)


# ==============================================================================
# 10. PENANGANAN PERMINTAAN HTTP (ROUTING)
# ==============================================================================
def handle_request(client_socket):
    """
    Menangani permintaan HTTP dari browser atau aplikasi client.
    Mendukung routing:
      - GET /            -> Dashboard status perangkat (HTML / JSON)
      - GET /api/status   -> Respons JSON lengkap status perangkat
    """
    try:
        raw_request = client_socket.recv(1024)
        if not raw_request:
            return

        request_text = raw_request.decode("utf-8", "ignore")
        lines = request_text.split("\r\n")
        if len(lines) == 0:
            return

        request_line = lines[0]
        parts = request_line.split()
        if len(parts) < 2:
            return

        method = parts[0]
        full_path = parts[1]

        # Pisahkan path dari query parameter jika ada
        path = full_path.split("?")[0]

        print(f"[HTTP] {method} {path}")

        # Tangani endpoint API status (JSON)
        if path == "/api/status":
            data = get_device_status()
            json_str = json.dumps(data)
            send_response(client_socket, 200, "application/json; charset=utf-8", json_str.encode("utf-8"))

        # Tangani endpoint utama (/)
        elif path == "/":
            # Jika client secara spesifik meminta JSON (Accept: application/json)
            if "application/json" in request_text and "text/html" not in request_text:
                data = get_device_status()
                json_str = json.dumps(data)
                send_response(client_socket, 200, "application/json; charset=utf-8", json_str.encode("utf-8"))
            else:
                html_body = render_dashboard_html()
                send_response(client_socket, 200, "text/html; charset=utf-8", html_body.encode("utf-8"))

        # Endpoint 404 (Tidak ditemukan)
        else:
            err_data = {"error": "Endpoint tidak ditemukan", "path": path, "code": 404}
            json_str = json.dumps(err_data)
            send_response(client_socket, 404, "application/json; charset=utf-8", json_str.encode("utf-8"))

    except Exception as e:
        print(f"[HTTP] Error memproses permintaan: {e}")
    finally:
        # Bersihkan memori RAM MicroPython
        gc.collect()


# ==============================================================================
# 11. SERVER UTAMA (NON-BLOCKING)
# ==============================================================================
def start_server(port=SERVER_PORT):
    """
    Menyiapkan dan membuka socket HTTP Server pada port yang ditentukan (default: 80).
    Socket diatur dengan timeout pendek agar non-blocking.
    """
    addr = socket.getaddrinfo("0.0.0.0", port)[0][-1]
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind(addr)
    server_socket.listen(5)
    server_socket.settimeout(0.5)  # Timeout 500ms agar loop utama tidak membeku

    print(f"[Server] HTTP Server berjalan di port {port}")
    return server_socket


# ==============================================================================
# 12. FUNGSI EKSEKUSI UTAMA (MAIN LOOP)
# ==============================================================================
def main():
    """
    Fungsi eksekusi utama sistem IoT ESP32.
    Mengatur alur: Inisialisasi -> Koneksi Wi-Fi -> Start Server -> Main Loop.
    """
    print("\n==================================================")
    print("      MEMULAI PROGRAM UTAMA ESP32 (MONU)          ")
    print("==================================================")

    # 1. Inisialisasi pin hardware
    init_hardware()

    # 2. Hubungkan ke Wi-Fi (DHCP)
    wifi_ok = connect_wifi(timeout_s=15)
    if not wifi_ok:
        print("[System] Melanjutkan tanpa Wi-Fi. ESP32 akan tetap mencoba koneksi.\n")

    # 3. Jalankan HTTP Server
    server_socket = start_server(SERVER_PORT)

    ip = get_ip_address()
    print("==================================================")
    print("                 STATUS SERVER SIAP               ")
    print("==================================================")
    print(f" URL Dashboard : http://{ip}/")
    print(f" Endpoint API  : http://{ip}/api/status")
    print("==================================================\n")
    print("[System] Siap melayani permintaan HTTP. Tekan Ctrl+C untuk berhenti.\n")

    # 4. Loop Utama
    while True:
        try:
            # A. Periksa dan jaga koneksi Wi-Fi secara berkala
            check_wifi_connection()

            # B. Tangani koneksi client yang masuk (Non-blocking)
            try:
                client_sock, client_addr = server_socket.accept()
                client_sock.settimeout(2.0)  # Timeout komunikasi client
                handle_request(client_sock)
                client_sock.close()
            except OSError:
                # Timeout normal ketika tidak ada client yang masuk dalam 500ms
                pass

            # C. Yield sejenak untuk stabilitas sistem
            time.sleep_ms(20)

        except KeyboardInterrupt:
            print("\n[System] Program dihentikan oleh pengguna.")
            if server_socket:
                server_socket.close()
            break
        except Exception as e:
            print(f"[System] Kesalahan pada main loop: {e}")
            time.sleep(1)


# Jalankan program jika dieksekusi sebagai main script
if __name__ == "__main__":
    main()
