# ==============================================================================
# TEST_THERMOCOUPLE.PY - DIAGNOSTIK & PENGUJIAN MANDIRI MAX6675
# ==============================================================================
# Program pengujian mandiri untuk memverifikasi modul MAX6675.
# Konfigurasi Pin sesuai PRD Seksi 4:
#   - SCK = GPIO 18
#   - SO  = GPIO 19
#   - CS  = GPIO 5
# ==============================================================================

import machine
import utime as time

PIN_SCK = 18
PIN_SO  = 19
PIN_CS  = 5

print("\n" + "=" * 65)
print("     DIAGNOSTIK MANDIRI THERMOCOUPLE TYPE-K + MAX6675      ")
print("=" * 65)
print(f" Pin SPI: SCK=GPIO {PIN_SCK}, SO=GPIO {PIN_SO}, CS=GPIO {PIN_CS}")
print("=" * 65 + "\n")

sck = machine.Pin(PIN_SCK, machine.Pin.OUT)
so  = machine.Pin(PIN_SO, machine.Pin.IN)
cs  = machine.Pin(PIN_CS, machine.Pin.OUT)

cs.value(1)   # Idle HIGH
sck.value(0)  # Idle LOW

def read_max6675_raw():
    cs.value(0)
    time.sleep_us(10)
    data = 0
    for _ in range(16):
        sck.value(1)
        time.sleep_us(5)
        data = (data << 1) | so.value()
        sck.value(0)
        time.sleep_us(5)
    cs.value(1)
    return data

print("Membaca MAX6675 setiap 1 detik. Tekan Ctrl+C untuk berhenti.\n")
print(f"{'No':<5} | {'Hex':<8} | {'Bit D2':<7} | {'Suhu (°C)':<10} | {'Status & Diagnostik'}")
print("-" * 75)

initial_temp = None
cycle = 0

try:
    while True:
        cycle += 1
        raw = read_max6675_raw()
        raw_hex = f"0x{raw:04X}"
        bit_d2 = (raw & 0x0004) >> 2

        diagnostic = "NORMAL"
        temp_c = None

        if raw == 0 or raw == 0xFFFF:
            diagnostic = "ERROR: Komunikasi SPI gagal! Cek kabel SCK, SO, CS & VCC/GND."
        elif bit_d2 == 1:
            diagnostic = "ERROR: Probe terputus (Open Circuit)! Kencangkan baut terminal."
        else:
            raw_temp = (raw >> 3) & 0x0FFF
            temp_c = raw_temp * 0.25

            if initial_temp is None:
                initial_temp = temp_c
                diagnostic = f"Suhu awal terukur ({temp_c:.2f}°C)"
            else:
                diff = temp_c - initial_temp
                if diff > 1.5:
                    diagnostic = f"SUHU MENINGKAT (+{diff:.2f}°C) -> POLARITAS BENAR OK"
                elif diff < -1.5:
                    diagnostic = f"PERINGATAN: SUHU TURUN ({diff:.2f}°C)! KABEL PROBE T+ & T- TERBALIK!"

        temp_str = f"{temp_c:.2f} °C" if temp_c is not None else "ERROR"
        print(f"{cycle:<5} | {raw_hex:<8} | {bit_d2:<7} | {temp_str:<10} | {diagnostic}")

        time.sleep(1)

except KeyboardInterrupt:
    print("\nPengujian dihentikan.")
    print("=" * 65)
    print("SOLUSI BILA SUHU TURUN SAAT PROBE DIPANASKAN:")
    print("Jika saat probe dipanaskan api suhunya MALAH TURUN (misal 30°C jadi 1°C):")
    print(">>> Tukar posisi kabel merah dan biru/kuning pada terminal modul MAX6675! <<<")
    print("=" * 65 + "\n")
