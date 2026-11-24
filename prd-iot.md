# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Sistem Monitoring dan Otomatisasi Penyiraman Berbasis IoT

### 1. Deskripsi Produk

Sistem ini merupakan perangkat Internet of Things (IoT) yang dirancang untuk memantau kondisi lingkungan melalui beberapa sensor dan melakukan tindakan otomatis berdasarkan hasil pembacaan sensor.

Sistem menggunakan ESP32 sebagai mikrokontroler utama yang menerima data dari sensor, mengendalikan pompa air melalui relay, serta mengirimkan notifikasi ke aplikasi ketika terdeteksi kondisi tertentu.

### 2. Tujuan Sistem

1. Memantau tingkat kelembapan tanah.
2. Mendeteksi kenaikan suhu lingkungan.
3. Mendeteksi keberadaan gas.
4. Memantau suhu menggunakan thermocouple.
5. Melakukan penyiraman atau pemompaan air secara otomatis berdasarkan kondisi sensor.
6. Mengirimkan notifikasi peringatan dan informasi aktivitas perangkat ke aplikasi.

### 3. Komponen Hardware

| No. | Komponen | Fungsi |
|---|---|---|
| 1 | ESP32 | Mikrokontroler utama untuk memproses data sensor dan mengendalikan perangkat. |
| 2 | Soil Moisture Sensor | Mengukur tingkat kelembapan tanah. |
| 3 | DHT11 | Mengukur suhu dan kelembapan udara. |
| 4 | MQ-2 | Mendeteksi keberadaan gas atau asap tertentu. |
| 5 | Thermocouple K-Type | Mengukur suhu pada titik tertentu. |
| 6 | MAX6675 | Mengubah pembacaan thermocouple menjadi data digital. |
| 7 | Relay | Mengontrol aktivasi pompa air. |
| 8 | Water Pump | Memompa air untuk proses penyiraman. |
| 9 | Power Supply | Menyediakan kebutuhan daya perangkat. |

### 4. Fungsionalitas Sistem

#### 4.1 Soil Moisture – Otomatisasi Kelembapan Tanah

- Sensor membaca tingkat kelembapan tanah secara berkala.
- Ketika tanah terdeteksi kering, ESP32 mengaktifkan relay.
- Relay mengaktifkan pompa air untuk melakukan penyiraman otomatis.
- Ketika kelembapan tanah sudah mencapai kondisi yang ditentukan, pompa berhenti.
- Sistem mengirimkan notifikasi ke aplikasi mengenai kondisi tanah dan aktivitas penyiraman.

#### 4.2 DHT11 – Monitoring Suhu Lingkungan

- DHT11 membaca suhu dan kelembapan udara secara berkala.
- Ketika suhu lingkungan melebihi batas yang ditentukan, sistem mengaktifkan pompa air secara otomatis.
- Pompa melakukan penyiraman sesuai mekanisme yang telah ditentukan.
- Sistem mengirimkan notifikasi ke aplikasi ketika suhu terdeteksi tinggi dan ketika penyiraman dilakukan.

#### 4.3 MQ-2 – Deteksi Gas dan Asap

- MQ-2 membaca perubahan konsentrasi gas atau asap yang dapat dideteksi sensor.
- Ketika nilai pembacaan melewati ambang batas yang ditentukan, sistem mengidentifikasi kondisi sebagai peringatan.
- Sistem mengirimkan notifikasi ke aplikasi sebagai informasi adanya indikasi gas atau asap.
- Sistem tetap melakukan pemantauan secara berkala.

#### 4.4 Thermocouple – Monitoring Suhu

- Thermocouple mengukur suhu pada titik pemasangan sensor.
- MAX6675 meneruskan hasil pengukuran ke ESP32.
- Ketika suhu melebihi batas yang ditentukan, ESP32 mengaktifkan relay.
- Relay mengaktifkan pompa air secara otomatis.
- Sistem mengirimkan notifikasi ke aplikasi mengenai kenaikan suhu dan aktivitas pompa.

### 5. Sistem Notifikasi Aplikasi

Setiap sensor memiliki jenis notifikasi sesuai kondisi yang terdeteksi.

| Sensor | Kondisi | Notifikasi |
|---|---|---|
| Soil Moisture | Tanah kering | Tanah terdeteksi kering. Penyiraman otomatis diaktifkan. |
| Soil Moisture | Kelembapan tercapai | Penyiraman selesai. |
| DHT11 | Suhu tinggi | Suhu lingkungan melebihi batas normal. |
| DHT11 | Pompa aktif | Penyiraman otomatis akibat suhu tinggi. |
| MQ-2 | Gas atau asap terdeteksi | Peringatan! Terdeteksi indikasi gas atau asap. |
| Thermocouple | Suhu tinggi | Peringatan! Suhu pada titik pengukuran melebihi batas. |
| Thermocouple | Pompa aktif | Pompa air diaktifkan berdasarkan pembacaan thermocouple. |

### 6. Alur Kerja Sistem

1. ESP32 mengaktifkan dan membaca seluruh sensor.
2. Data sensor diproses dan dibandingkan dengan ambang batas yang telah ditentukan.
3. Jika tanah kering, sistem mengaktifkan pompa air.
4. Jika suhu DHT11 tinggi, sistem mengaktifkan pompa air.
5. Jika MQ-2 mendeteksi indikasi gas atau asap, sistem mengirimkan notifikasi peringatan.
6. Jika thermocouple mendeteksi suhu tinggi, sistem mengaktifkan pompa air.
7. Setiap perubahan kondisi dan aktivitas perangkat dikirimkan ke aplikasi.
8. Sistem kembali melakukan pemantauan secara berkala.

### 7. Kriteria Keberhasilan

Sistem dinyatakan berhasil apabila:

1. Seluruh sensor dapat membaca kondisi sesuai fungsinya.
2. ESP32 dapat menerima dan memproses data sensor.
3. Pompa air dapat aktif secara otomatis berdasarkan kondisi yang ditentukan.
4. Relay dapat mengendalikan pompa sesuai perintah ESP32.
5. Sensor MQ-2 dapat memicu notifikasi ketika melewati ambang deteksi.
6. Sistem dapat mengirimkan notifikasi ke aplikasi.
7. Sistem dapat melakukan pemantauan secara berkala dan berkelanjutan.