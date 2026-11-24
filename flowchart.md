
# FLOWCHART SISTEM IoT

## 1. Flowchart Utama

```mermaid
flowchart TD
    A([Mulai]) --> B[Inisialisasi ESP32 dan seluruh sensor]
    B --> C[Baca data Soil Moisture]
    C --> D[Baca data DHT11]
    D --> E[Baca data MQ-2]
    E --> F[Baca data Thermocouple melalui MAX6675]

    F --> G{Tanah kering?}
    G -->|Ya| H[Aktifkan Relay dan Pompa]
    G -->|Tidak| I{Suhu DHT11 tinggi?}
    H --> J[Kirim notifikasi aplikasi]
    J --> I

    I -->|Ya| K[Aktifkan Relay dan Pompa]
    I -->|Tidak| L{Gas melewati ambang batas?}
    K --> M[Kirim notifikasi aplikasi]
    M --> L

    L -->|Ya| N[Kirim notifikasi peringatan gas]
    L -->|Tidak| O{Suhu Thermocouple tinggi?}
    N --> O

    O -->|Ya| P[Aktifkan Relay dan Pompa]
    O -->|Tidak| Q[Perbarui data monitoring aplikasi]
    P --> R[Kirim notifikasi aplikasi]
    R --> Q

    Q --> S[Ulangi pembacaan sensor]
    S --> C
```

## 2. Flowchart Soil Moisture

```mermaid
flowchart TD
    A([Mulai]) --> B[Baca kelembapan tanah]
    B --> C{Tanah kering?}
    C -->|Ya| D[Aktifkan Relay]
    D --> E[Pompa menyiram tanah]
    E --> F{Kelembapan sudah tercapai?}
    F -->|Belum| E
    F -->|Sudah| G[Matikan Pompa]
    G --> H[Kirim notifikasi penyiraman selesai]
    C -->|Tidak| I[Monitoring kelembapan]
    H --> J([Kembali monitoring])
    I --> J
```

## 3. Flowchart DHT11

```mermaid
flowchart TD
    A([Mulai]) --> B[Baca suhu lingkungan]
    B --> C{Suhu melebihi batas?}
    C -->|Ya| D[Kirim notifikasi suhu tinggi]
    D --> E[Aktifkan Relay dan Pompa]
    E --> F[Proses penyiraman otomatis]
    F --> G[Matikan Pompa sesuai kondisi berhenti]
    G --> H[Kirim notifikasi penyiraman selesai]
    C -->|Tidak| I[Monitoring suhu]
    H --> J([Kembali monitoring])
    I --> J
```

## 4. Flowchart MQ-2

```mermaid
flowchart TD
    A([Mulai]) --> B[Baca nilai sensor MQ-2]
    B --> C{Nilai gas melewati ambang?}
    C -->|Ya| D[Identifikasi indikasi gas atau asap]
    D --> E[Kirim notifikasi peringatan ke aplikasi]
    E --> F[Perbarui status monitoring]
    C -->|Tidak| G[Monitoring normal]
    F --> H([Kembali monitoring])
    G --> H
```

## 5. Flowchart Thermocouple

```mermaid
flowchart TD
    A([Mulai]) --> B[Baca suhu thermocouple melalui MAX6675]
    B --> C{Suhu melebihi batas?}
    C -->|Ya| D[Kirim notifikasi suhu tinggi]
    D --> E[Aktifkan Relay dan Pompa]
    E --> F[Proses pemompaan air]
    F --> G{Suhu sudah mencapai batas aman?}
    G -->|Belum| F
    G -->|Sudah| H[Matikan Pompa]
    H --> I[Kirim notifikasi pemompaan selesai]
    C -->|Tidak| J[Monitoring suhu]
    I --> K([Kembali monitoring])
    J --> K
```

## 6. Keterangan Simbol

| Simbol | Keterangan |
|---|---|
| Oval | Mulai atau selesai |
| Persegi panjang | Proses atau aktivitas |
| Belah ketupat | Keputusan atau kondisi |
| Panah | Arah alur proses |

## 7. Keterangan Sistem

- ESP32 berfungsi sebagai pusat kendali seluruh perangkat.
- Soil Moisture mendeteksi kondisi kelembapan tanah.
- DHT11 memantau suhu dan kelembapan udara.
- MQ-2 mendeteksi indikasi gas atau asap.
- Thermocouple mengukur suhu pada titik pemasangan.
- Relay mengendalikan pompa air.
- Aplikasi menerima notifikasi dari seluruh sensor.
- Proses monitoring berlangsung secara berulang.
