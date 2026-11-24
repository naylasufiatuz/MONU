/// ============================================================
///  PENGATURAN KONEKSI IoT
///  Semua yang perlu kamu isi untuk menyambungkan alat ada di sini.
///  Bagian bertanda "ISI DI SINI" adalah yang boleh kamu ubah.
/// ============================================================
class IotConfig {
  IotConfig._();

  // ISI DI SINI ------------------------------------------------

  /// true  = Mode Demo (data palsu, tidak butuh alat maupun internet).
  /// false = Mode Asli (membaca data dari Firebase Realtime Database).
  /// Pilihan ini juga bisa diganti dari dalam app
  /// (Profil > Pengaturan Koneksi IoT) tanpa mengubah file ini.
  static const bool useMockData = true;

  /// ISI DI SINI: alamat Realtime Database dari Firebase.
  /// Contoh: https://nama-proyek-default-rtdb.firebaseio.com
  static const String firebaseDatabaseUrl = 'ISI_URL_DATABASE_DI_SINI';

  /// ISI DI SINI: ID perangkat. Harus sama dengan yang dipakai ESP32.
  static const String deviceId = 'monu-node-1';

  /// ISI DI SINI: IP Address default ESP32 untuk koneksi langsung.
  static const String defaultEsp32Ip = '192.168.1.100';

  /// Interval polling untuk pengambilan data langsung dari ESP32 (2 detik).
  static const Duration esp32PollInterval = Duration(seconds: 2);

  // ------------------------------------------------------------

  /// Lokasi data terbaru di database: devices/{deviceId}
  static const String devicesPath = 'devices';

  /// Lokasi riwayat di database: history/{deviceId}/{id-otomatis}
  static const String historyPath = 'history';

  /// Perangkat dianggap Offline jika tidak ada data baru selama ini (PRD: 30 detik).
  static const Duration offlineAfter = Duration(seconds: 30);

  /// Seberapa sering app mengambil data di Mode Asli.
  static const Duration pollInterval = Duration(seconds: 5);

  /// Seberapa sering data palsu dibuat di Mode Demo.
  static const Duration mockInterval = Duration(seconds: 5);

  /// Jumlah titik pada grafik mini.
  static const int sparklinePoints = 30;
}