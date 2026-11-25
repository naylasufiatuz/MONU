# PRODUCT REQUIREMENTS DOCUMENT (PRD)
# SISTEM MONITORING DAN OTOMATISASI BERBASIS IoT ESP32

## 1. Informasi Proyek

**Nama Proyek:** Sistem Monitoring dan Otomatisasi IoT  
**Mikrokontroler:** ESP32 DevKit  
**Framework:** MicroPython  
**Development Environment:** Thonny IDE  
**File Utama:** `main.py`

Sistem ini menggunakan ESP32 untuk membaca beberapa sensor lingkungan, mendeteksi kondisi tertentu, mengendalikan pompa air dan buzzer secara otomatis, serta menyediakan data yang nantinya dapat diintegrasikan dengan aplikasi Flutter.

## 2. Tujuan Sistem

1. Membaca suhu lingkungan dan kelembapan udara.
2. Membaca suhu menggunakan thermocouple tipe K.
3. Mendeteksi gas menggunakan MQ-2.
4. Mengukur kelembapan tanah.
5. Mengendalikan relay dan pompa air secara otomatis.
6. Memberikan peringatan melalui buzzer.
7. Menyediakan data sensor yang konsisten dan mudah diintegrasikan dengan aplikasi.

## 3. Daftar Komponen Hardware

| No. | Komponen | Fungsi |
|---|---|---|
| 1 | ESP32 DevKit | Mikrokontroler utama |
| 2 | ESP32 Expansion Board | Mempermudah koneksi komponen |
| 3 | Thermocouple Type-K + MAX6675 | Mengukur suhu melalui probe |
| 4 | MQ-2 | Mendeteksi keberadaan gas tertentu |
| 5 | DHT11 | Mengukur suhu dan kelembapan udara |
| 6 | Soil Moisture Sensor | Mengukur kelembapan tanah |
| 7 | Relay Module | Mengontrol pompa |
| 8 | Mini Water Pump | Menyiram tanah |
| 9 | Buzzer 3 Pin | Memberikan peringatan suara |
| 10 | Adaptor 12V | Sumber daya pompa |

## 4. Konfigurasi Pin ESP32

Gunakan konfigurasi berikut sebagai konfigurasi awal. Jangan mengubah GPIO tanpa alasan teknis yang jelas.

| Komponen | Pin ESP32 |
|---|---|
| MAX6675 SCK | GPIO 18 |
| MAX6675 SO | GPIO 19 |
| MAX6675 CS | GPIO 5 |
| MQ-2 AO | GPIO 34 |
| DHT11 DATA | GPIO 4 |
| Soil Moisture AO | GPIO 35 |
| Relay IN | GPIO 26 |
| Buzzer IO | GPIO 27 |

Catatan:
- Semua komponen harus menggunakan GND bersama sesuai kebutuhan rangkaian.
- Pastikan tegangan keluaran MQ-2 tidak melebihi batas input ADC ESP32 sebesar 3,3V. Gunakan rangkaian pembagi tegangan atau pengondisi sinyal yang sesuai.
- GPIO 34 dan GPIO 35 hanya digunakan sebagai input.
- Tegangan suplai setiap modul harus mengikuti spesifikasi komponennya.
- Pompa tidak boleh mengambil daya langsung dari GPIO ESP32.

## 5. Kebutuhan Pembacaan Sensor

### 5.1 Thermocouple Type-K MAX6675

Thermocouple digunakan untuk mengukur suhu pada ujung probe.

**Masalah yang harus diperbaiki:**

Saat probe thermocouple mengalami peningkatan suhu, nilai yang terbaca justru mengalami penurunan. Contohnya, suhu awal sekitar 30°C justru berubah menjadi sekitar 1°C ketika probe dipanaskan.

Antigravity wajib melakukan pemeriksaan menyeluruh terhadap masalah ini.

Hal yang wajib diperiksa:

1. Pastikan urutan kabel thermocouple tipe K sesuai polaritas positif dan negatif.
2. Periksa koneksi thermocouple dengan modul MAX6675.
3. Pastikan konfigurasi pin SCK, SO, dan CS benar.
4. Periksa komunikasi SPI atau metode pembacaan MAX6675 yang digunakan.
5. Pastikan urutan bit saat membaca data sudah benar.
6. Pastikan perhitungan data mentah menjadi Celsius sesuai datasheet MAX6675.
7. Periksa status thermocouple disconnected.
8. Pastikan nilai error tidak dianggap sebagai nilai suhu yang valid.

**Kriteria keberhasilan:**

- Suhu dapat terbaca dalam satuan Celsius.
- Ketika suhu probe meningkat, hasil pengukuran juga meningkat.
- Ketika suhu probe menurun, hasil pengukuran ikut menurun.
- Sensor yang terputus harus menghasilkan status error, bukan angka suhu palsu.
- Nilai sensor tidak boleh dimanipulasi agar terlihat normal.

### 5.2 Sensor MQ-2

Digunakan untuk mendeteksi perubahan konsentrasi gas yang dapat dideteksi oleh MQ-2.

Kebutuhan:
- Membaca nilai analog melalui GPIO 34.
- Menampilkan nilai ADC mentah.
- Memiliki threshold yang dapat dikonfigurasi.
- Memiliki proses pemanasan sensor sebelum pembacaan digunakan.
- Membedakan kondisi normal, terdeteksi, dan sensor bermasalah.

Catatan: Nilai ADC bukan satuan ppm. Jangan mengklaim konsentrasi gas dalam ppm tanpa kalibrasi dan metode pengukuran yang sesuai.

### 5.3 Sensor DHT11

Digunakan untuk mengukur:
- Suhu udara dalam Celsius.
- Kelembapan udara dalam persen.

Kebutuhan:
- Membaca suhu dan kelembapan melalui GPIO 4.
- Menghindari pembacaan terlalu cepat.
- Menangani kegagalan komunikasi sensor.
- Tidak menghentikan seluruh sistem ketika sensor gagal dibaca.

### 5.4 Soil Moisture Sensor

Digunakan untuk mengetahui tingkat kelembapan tanah.

Kebutuhan:
- Membaca data analog melalui GPIO 35.
- Menampilkan nilai ADC mentah.
- Menghasilkan nilai persentase kelembapan berdasarkan hasil kalibrasi.
- Membedakan kondisi tanah kering, cukup lembap, dan basah.
- Threshold harus dapat diubah melalui konfigurasi.

Jangan mengasumsikan nilai ADC tertentu sebagai nilai kering atau basah tanpa proses kalibrasi.

## 6. Sistem Aktuator

### 6.1 Relay dan Mini Water Pump

Relay digunakan untuk mengontrol pompa air.

Kebutuhan:
- Relay dapat diaktifkan dan dinonaktifkan melalui ESP32.
- Status pompa harus dapat diketahui dari program.
- Logika active-low atau active-high harus diverifikasi berdasarkan modul relay.
- Pompa menggunakan sumber daya eksternal sesuai spesifikasi.
- Tambahkan batas waktu maksimum pompa menyala untuk mencegah pompa berjalan terus-menerus akibat kesalahan pembacaan sensor.

### 6.2 Buzzer

Buzzer menggunakan koneksi tiga pin:

- IO
- GND
- VCC

Kebutuhan:
- Dapat dinyalakan dan dimatikan.
- Mendukung PWM apabila jenis buzzer memerlukannya.
- Frekuensi dan duty cycle dapat dikonfigurasi.
- Tidak mengganggu pembacaan sensor lainnya.

Antigravity wajib memastikan jenis buzzer berdasarkan karakteristik modul, bukan langsung mengasumsikan semua buzzer menggunakan PWM.

## 7. Logika Otomatisasi Sistem

Sistem harus menggunakan kombinasi kondisi berikut.

| Kondisi | Pompa | Buzzer |
|---|---|---|
| Semua sensor normal | OFF | OFF |
| Tanah kering | ON | OFF |
| Gas terdeteksi | OFF | ON |
| Suhu udara tinggi | ON | ON |
| Suhu thermocouple tinggi | ON | ON |

Ketentuan tambahan:

1. Kondisi tanah kering mengaktifkan pompa secara otomatis.
2. Kondisi gas terdeteksi mengaktifkan buzzer tanpa mengaktifkan pompa.
3. Suhu udara yang melewati threshold mengaktifkan pompa dan buzzer.
4. Suhu thermocouple yang melewati threshold mengaktifkan pompa dan buzzer.
5. Jika beberapa kondisi terjadi bersamaan, seluruh output harus mengikuti kombinasi logika yang telah ditentukan.
6. Kondisi normal harus mengembalikan pompa dan buzzer ke keadaan OFF.
7. Threshold setiap sensor harus disimpan dalam bagian konfigurasi agar mudah disesuaikan.

**Prioritas logika:**

- Pompa ON jika tanah kering ATAU suhu udara tinggi ATAU suhu thermocouple tinggi.
- Buzzer ON jika gas terdeteksi ATAU suhu udara tinggi ATAU suhu thermocouple tinggi.

## 8. Arsitektur Program

Program harus menggunakan struktur modular agar mudah dikembangkan.

Struktur yang direkomendasikan:

```text
iot-system/
│
├── main.py
├── config.py
├── sensors/
│   ├── thermocouple.py
│   ├── mq2.py
│   ├── dht11.py
│   └── soil_moisture.py
│
├── actuators/
│   ├── relay.py
│   └── buzzer.py
│
└── README.md
```

Jika keterbatasan MicroPython atau konfigurasi Thonny membuat struktur modular tidak memungkinkan, seluruh program boleh dibuat dalam `main.py`, tetapi setiap fungsi harus tetap dipisahkan secara logis.

## 9. Format Data Monitoring

Program harus menghasilkan data yang konsisten.

Contoh format data:

```json
{
  "temperature": 30.5,
  "humidity": 70,
  "thermocouple_temperature": 32.25,
  "gas_value": 1200,
  "soil_value": 1800,
  "soil_moisture": 55,
  "gas_detected": false,
  "soil_dry": false,
  "pump_status": false,
  "buzzer_status": false,
  "system_status": "normal"
}
```

Ketentuan:
- Semua data sensor harus memiliki nama yang konsisten.
- Gunakan `null` untuk data yang gagal dibaca.
- Tambahkan status error jika sensor tidak terhubung atau gagal dibaca.
- Jangan mengirim angka palsu untuk menggantikan sensor yang error.
- Format harus mudah digunakan untuk integrasi WiFi dan Flutter.

## 10. Kebutuhan WiFi dan Integrasi Aplikasi

Sistem harus disiapkan untuk pengembangan komunikasi dengan aplikasi Flutter.

Kebutuhan:
1. ESP32 dapat terhubung ke jaringan WiFi.
2. SSID dan password disimpan dalam konfigurasi.
3. ESP32 mendapatkan alamat IP secara otomatis dari router.
4. Alamat IP ditampilkan pada serial monitor.
5. Sistem menyediakan data sensor melalui mekanisme komunikasi yang dapat dikembangkan, seperti HTTP API atau MQTT.
6. Pembacaan sensor dan pengendalian aktuator tetap berjalan ketika koneksi WiFi terputus.
7. Sistem melakukan percobaan koneksi ulang secara berkala.

Untuk tahap awal, prioritaskan pembacaan sensor dan otomatisasi lokal sebelum mengimplementasikan komunikasi aplikasi.

## 11. Error Handling dan Stabilitas

Program harus mampu menangani:
- Thermocouple terputus.
- MAX6675 gagal dibaca.
- MQ-2 tidak memberikan data yang valid.
- DHT11 mengalami kegagalan komunikasi.
- Soil moisture tidak memberikan pembacaan.
- WiFi terputus.
- Relay tidak merespons sesuai perintah.
- Kegagalan program yang menyebabkan output berada dalam kondisi tidak terkontrol.

Program tidak boleh berhenti total hanya karena satu sensor mengalami error.

Jika terjadi kegagalan pembacaan, tandai sensor tersebut sebagai error dan jangan gunakan data yang tidak valid untuk mengambil keputusan otomatis.

## 12. Kebutuhan Serial Monitor

Serial Monitor harus menampilkan informasi secara terstruktur.

Contoh:

```text
================================
        IOT MONITORING
================================

Air Temperature : 30.5 C
Air Humidity    : 70 %
Thermocouple    : 32.25 C
MQ-2 Value      : 1200
Soil Value      : 1800
Soil Moisture   : 55 %

Gas Status      : NORMAL
Soil Status     : MOIST
Pump Status     : OFF
Buzzer Status   : OFF
System Status   : NORMAL

================================
```

Jika sensor gagal dibaca, tampilkan pesan error yang jelas.

## 13. Tahapan Pengembangan

Antigravity wajib mengerjakan proyek secara bertahap.

**Tahap 1 — Audit Hardware dan Pin**
- Periksa seluruh konfigurasi GPIO.
- Periksa kesesuaian tegangan.
- Periksa koneksi setiap sensor.
- Identifikasi jenis modul buzzer dan relay.

**Tahap 2 — Perbaikan Thermocouple**
- Fokus menyelesaikan masalah pembacaan suhu terbalik.
- Periksa polaritas, koneksi, komunikasi, dan rumus.
- Jangan lanjut menganggap sensor berhasil sebelum pengujian kenaikan dan penurunan suhu berhasil.

**Tahap 3 — Pengujian Sensor Individual**
- Uji MQ-2.
- Uji DHT11.
- Uji Soil Moisture.
- Uji Thermocouple.
- Pastikan seluruh sensor menghasilkan data yang masuk akal.

**Tahap 4 — Pengujian Aktuator**
- Uji relay.
- Uji pompa.
- Uji buzzer.

**Tahap 5 — Integrasi Otomatisasi**
- Gabungkan seluruh sensor.
- Terapkan logika otomatisasi.
- Pastikan output tidak saling bertentangan.

**Tahap 6 — Integrasi WiFi**
- Hubungkan ESP32 ke WiFi.
- Tampilkan alamat IP.
- Siapkan endpoint atau mekanisme komunikasi untuk aplikasi.

**Tahap 7 — Pengujian Akhir**
- Uji seluruh sistem.
- Periksa kestabilan pembacaan.
- Periksa respons aktuator.
- Pastikan sistem dapat berjalan terus-menerus tanpa crash.

## 14. Acceptance Criteria

Proyek dianggap selesai jika:

- [ ] Semua sensor berhasil terdeteksi.
- [ ] Thermocouple menunjukkan kenaikan suhu ketika probe semakin panas.
- [ ] Thermocouple menunjukkan penurunan suhu ketika probe mendingin.
- [ ] Kesalahan pembacaan MAX6675 dapat ditangani.
- [ ] MQ-2 menghasilkan pembacaan analog yang stabil setelah pemanasan.
- [ ] DHT11 menampilkan suhu dan kelembapan.
- [ ] Soil moisture dapat membedakan kondisi tanah kering dan basah setelah kalibrasi.
- [ ] Relay dapat mengontrol pompa.
- [ ] Buzzer dapat berbunyi sesuai jenis modulnya.
- [ ] Logika otomatisasi berjalan sesuai tabel.
- [ ] Error satu sensor tidak membuat seluruh sistem berhenti.
- [ ] ESP32 dapat terhubung ke WiFi.
- [ ] Alamat IP tampil di Serial Monitor.
- [ ] Data siap digunakan oleh aplikasi Flutter.

## 15. Instruksi Khusus untuk Antigravity

Jangan langsung membuat kode tanpa menganalisis masalah yang ada.

Lakukan langkah berikut:

1. Audit seluruh kebutuhan hardware dan konfigurasi GPIO.
2. Identifikasi penyebab thermocouple membaca suhu terbalik.
3. Periksa kompatibilitas library MicroPython dengan firmware ESP32.
4. Gunakan dokumentasi dan datasheet komponen sebagai acuan.
5. Jangan membuat nilai sensor palsu atau memanipulasi hasil pembacaan.
6. Jangan mengubah konfigurasi pin tanpa alasan teknis.
7. Jangan menghilangkan fitur atau sensor yang tercantum dalam PRD.
8. Pastikan seluruh fungsi dapat berjalan pada MicroPython dan Thonny IDE.
9. Buat kode yang modular, mudah dibaca, dan mudah dikembangkan.
10. Berikan instruksi instalasi, konfigurasi, dan pengujian.
11. Berikan penjelasan penyebab error yang ditemukan.
12. Jangan menyatakan proyek berhasil sebelum seluruh acceptance criteria diuji.

**Prioritas utama: memperbaiki pembacaan thermocouple yang terbalik, memastikan semua sensor terbaca dengan benar, lalu mengintegrasikan seluruh sistem.**