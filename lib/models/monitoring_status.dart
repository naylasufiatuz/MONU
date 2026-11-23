import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';

/// Tingkat satu sensor.
enum SensorLevel { normal, warning, check, unavailable }

/// Status keseluruhan (PRD bagian 11).
enum MonitoringStatus { normal, warning, check, incomplete, offline }

extension SensorLevelX on SensorLevel {
  String get label => switch (this) {
        SensorLevel.normal => 'Normal',
        SensorLevel.warning => 'Waspada',
        SensorLevel.check => 'Perlu Pemeriksaan',
        SensorLevel.unavailable => 'Tidak tersedia',
      };

  Color get color => switch (this) {
        SensorLevel.normal => AppColors.safe,
        SensorLevel.warning => AppColors.warning,
        SensorLevel.check => AppColors.danger,
        SensorLevel.unavailable => AppColors.inkSoft,
      };

  IconData get icon => switch (this) {
        SensorLevel.normal => Icons.check_circle_outline,
        SensorLevel.warning => Icons.warning_amber_rounded,
        SensorLevel.check => Icons.error_outline,
        SensorLevel.unavailable => Icons.help_outline,
      };

  /// true jika level ini perlu ditampilkan sebagai peringatan.
  bool get isAlert =>
      this == SensorLevel.warning || this == SensorLevel.check;
}

extension MonitoringStatusX on MonitoringStatus {
  String get label => switch (this) {
        MonitoringStatus.normal => 'Normal',
        MonitoringStatus.warning => 'Waspada',
        MonitoringStatus.check => 'Perlu Pemeriksaan',
        MonitoringStatus.incomplete => 'Data Tidak Lengkap',
        MonitoringStatus.offline => 'Offline',
      };

  Color get color => switch (this) {
        MonitoringStatus.normal => AppColors.safe,
        MonitoringStatus.warning => AppColors.warning,
        MonitoringStatus.check => AppColors.danger,
        MonitoringStatus.incomplete => AppColors.inkSoft,
        MonitoringStatus.offline => AppColors.inkSoft,
      };

  IconData get icon => switch (this) {
        MonitoringStatus.normal => Icons.check_circle_outline,
        MonitoringStatus.warning => Icons.warning_amber_rounded,
        MonitoringStatus.check => Icons.error_outline,
        MonitoringStatus.incomplete => Icons.help_outline,
        MonitoringStatus.offline => Icons.wifi_off,
      };

  String get description => switch (this) {
        MonitoringStatus.normal =>
          'Semua pembacaan berada dalam rentang normal.',
        MonitoringStatus.warning =>
          'Ada pembacaan yang melewati ambang peringatan.',
        MonitoringStatus.check =>
          'Pembacaan perlu diperiksa lebih lanjut pada miniatur hutan.',
        MonitoringStatus.incomplete =>
          'Ada sensor yang gagal dibaca, jadi kondisi belum bisa dinyatakan normal.',
        MonitoringStatus.offline =>
          'Tidak ada data baru. Nilai yang tampil adalah data terakhir.',
      };
}