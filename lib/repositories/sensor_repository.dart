import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:monu/models/device_snapshot.dart';

/// Sumber data. Ada dua: Mock (demo) dan Firebase (asli).
/// Tampilan hanya bicara dengan class ini, jadi mengganti sumber data
/// tidak perlu mengubah tampilan.
abstract class SensorRepository {
  String get modeLabel;

  /// true jika sumber ini bisa memberi riwayat.
  bool get supportsHistory;

  /// Aliran data terbaru. Event null = belum ada data sama sekali.
  Stream<DeviceSnapshot?> watchLatest();

  /// Ambil data sekarang juga (dipakai untuk tarik-untuk-muat-ulang).
  Future<void> refresh();

  /// Riwayat pembacaan dalam rentang waktu terakhir, urut dari yang terlama.
  Future<List<DeviceSnapshot>> loadHistory(Duration range);

  void dispose();
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mengubah error teknis menjadi pesan yang mudah dipahami.
String describeRepositoryError(Object error) {
  if (error is RepositoryException) return error.message;
  if (error is TimeoutException) {
    return 'Waktu tunggu habis. Periksa koneksi internet dan URL database.';
  }
  if (error is http.ClientException) {
    return 'Tidak bisa terhubung ke database. Periksa koneksi internet dan URL database.';
  }
  if (error is FormatException) {
    return 'Isi database bukan JSON yang valid.';
  }
  return 'Terjadi kesalahan: $error';
}