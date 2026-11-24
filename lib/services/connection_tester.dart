import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:monu/config/iot_config.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/repositories/firebase_sensor_repository.dart';
import 'package:monu/repositories/sensor_repository.dart';

enum TestOutcome { success, warning, failure }

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.outcome,
    required this.message,
    this.detail,
  });

  final TestOutcome outcome;
  final String message;
  final String? detail;
}

/// Dipakai tombol "Tes Koneksi" di halaman Pengaturan Koneksi IoT.
class ConnectionTester {
  ConnectionTester._();

  /// Memvalidasi format alamat IP (IPv4) atau hostname
  static bool isValidIp(String input) {
    final String clean = input.trim().replaceAll('http://', '').replaceAll('/', '');
    if (clean.isEmpty) return false;
    if (clean == 'localhost' || clean.endsWith('.local')) return true;

    final RegExp ipv4Regex = RegExp(
      r'^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.'
      r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.'
      r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.'
      r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipv4Regex.hasMatch(clean);
  }

  /// Menguji koneksi langsung ke ESP32 melalui endpoint `GET http://<IP_ESP32>/api/status`
  static Future<ConnectionTestResult> testEsp32({
    required String ipAddress,
  }) async {
    String clean = ipAddress.trim();
    if (clean.startsWith('http://')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('https://')) {
      clean = clean.substring(8);
    }
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    if (clean.isEmpty) {
      return const ConnectionTestResult(
        outcome: TestOutcome.failure,
        message: 'Tidak Terhubung',
        detail: 'IP Address ESP32 belum diisi.',
      );
    }

    if (!isValidIp(clean)) {
      return const ConnectionTestResult(
        outcome: TestOutcome.failure,
        message: 'Format IP Address tidak valid',
        detail: 'Masukkan alamat IPv4 yang sesuai, contoh: 192.168.1.100',
      );
    }

    final Uri uri = Uri.parse('http://$clean/api/status');
    try {
      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) {
        return ConnectionTestResult(
          outcome: TestOutcome.failure,
          message: 'Tidak Terhubung (HTTP ${res.statusCode})',
          detail: 'ESP32 merespons dengan kode error ${res.statusCode}.',
        );
      }

      final dynamic data = jsonDecode(res.body);
      if (data == null || data is! Map) {
        return const ConnectionTestResult(
          outcome: TestOutcome.failure,
          message: 'Format data tidak sesuai',
          detail: 'Respons dari ESP32 bukan format JSON yang valid.',
        );
      }

      final dynamic wifi = data['wifi'];
      final bool isWifiConnected = data['wifi_connected'] == true ||
          (wifi is Map && (wifi['connected'] == true || wifi['status'] == 'terhubung')) ||
          data['device_status'] == 'online' ||
          data['status'] == 'online';

      final String actualIp = (wifi is Map ? wifi['ip_address']?.toString() : null) ??
          data['ip_address']?.toString() ??
          clean;
      final String deviceName = (data['device_name'] ?? data['device_id'] ?? 'ESP32 Node').toString();
      final String uptime = data['uptime_human']?.toString() ?? '-';

      if (!isWifiConnected) {
        return ConnectionTestResult(
          outcome: TestOutcome.warning,
          message: 'Terhubung Sebagian (Wi-Fi ESP32 Terputus)',
          detail: 'Berhasil menghubungi ESP32, namun status jaringan ESP32 terputus.',
        );
      }

      return ConnectionTestResult(
        outcome: TestOutcome.success,
        message: 'Terhubung',
        detail: 'Berhasil terhubung ke $deviceName ($actualIp) • Uptime: $uptime',
      );
    } catch (error) {
      return ConnectionTestResult(
        outcome: TestOutcome.failure,
        message: 'Tidak Terhubung',
        detail: describeRepositoryError(error),
      );
    }
  }

  static Future<ConnectionTestResult> test({
    required String databaseUrl,
    required String deviceId,
  }) async {
    final String? base = FirebaseSensorRepository.normalizeUrl(databaseUrl);
    if (base == null) {
      return const ConnectionTestResult(
        outcome: TestOutcome.failure,
        message: 'URL database belum benar.',
        detail:
            'Isi dengan alamat lengkap yang diawali https://, contoh: https://nama-proyek-default-rtdb.firebaseio.com',
      );
    }

    final Uri uri = Uri.parse('$base/${IotConfig.devicesPath}/$deviceId.json');

    try {
      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return const ConnectionTestResult(
          outcome: TestOutcome.failure,
          message: 'Akses ditolak oleh database.',
          detail:
              'Buka Firebase Console > Realtime Database > Rules, lalu izinkan baca.',
        );
      }
      if (res.statusCode == 404) {
        return const ConnectionTestResult(
          outcome: TestOutcome.failure,
          message: 'Database tidak ditemukan.',
          detail: 'Periksa lagi URL database. Pastikan tidak ada salah ketik.',
        );
      }
      if (res.statusCode != 200) {
        return ConnectionTestResult(
          outcome: TestOutcome.failure,
          message: 'Database membalas dengan kode ${res.statusCode}.',
        );
      }

      final dynamic data = jsonDecode(res.body);
      if (data == null) {
        return ConnectionTestResult(
          outcome: TestOutcome.warning,
          message: 'Terhubung ke database, tapi belum ada data.',
          detail:
              'Belum ada data di ${IotConfig.devicesPath}/$deviceId. Pastikan ESP32 menyala, terhubung Wi-Fi, dan memakai ID perangkat yang sama.',
        );
      }
      if (data is! Map) {
        return const ConnectionTestResult(
          outcome: TestOutcome.failure,
          message: 'Format data tidak sesuai.',
          detail: 'Data di devices/{id} harus berupa objek JSON.',
        );
      }

      final DeviceSnapshot snap = DeviceSnapshot.fromMap(deviceId, data);
      final Duration age = DateTime.now().difference(snap.timestamp);
      final List<String> missing = [
        for (final SensorSpec s in SensorConfig.all)
          if (snap.valueOf(s.id) == null) s.name,
      ];

      final StringBuffer detail = StringBuffer(
        'Data terakhir: ${Fmt.ago(age)} (${Fmt.dateTime(snap.timestamp)}).',
      );
      if (missing.isNotEmpty) {
        detail.write(' Belum terbaca: ${missing.join(', ')}.');
      }

      if (age > IotConfig.offlineAfter) {
        return ConnectionTestResult(
          outcome: TestOutcome.warning,
          message: 'Terhubung, tapi datanya sudah lama.',
          detail:
              '${detail.toString()} ESP32 mungkin mati atau jaringannya terputus.',
        );
      }

      return ConnectionTestResult(
        outcome: TestOutcome.success,
        message: 'Berhasil! Data diterima dari "${snap.deviceName}".',
        detail: detail.toString(),
      );
    } catch (error) {
      return ConnectionTestResult(
        outcome: TestOutcome.failure,
        message: 'Tidak bisa terhubung.',
        detail: describeRepositoryError(error),
      );
    }
  }
}