import 'package:flutter/material.dart';

/// high = nilai TINGGI dianggap berbahaya (contoh: suhu, MQ-2).
/// low  = nilai RENDAH dianggap berbahaya (contoh: kelembapan udara).
enum ThresholdDirection { high, low }

/// Dua ambang: Waspada dan Perlu Pemeriksaan.
/// Arah high: warning < check. Arah low: warning > check.
class AlertLimit {
  const AlertLimit({required this.warning, required this.check});

  final double warning;
  final double check;
}

/// Penjelasan satu sensor. Daftarnya ada di lib/config/sensor_config.dart.
class SensorSpec {
  const SensorSpec({
    required this.id,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.icon,
    required this.decimals,
    required this.direction,
    required this.defaultThreshold,
    required this.minValue,
    required this.maxValue,
    required this.description,
    required this.interpretation,
    required this.limitation,
    this.isRaw = false,
    this.canTriggerCheckAlone = true,
  });

  /// Kunci di JSON database (contoh: "temperature").
  final String id;
  final String name;
  final String shortName;
  final String unit;
  final IconData icon;
  final int decimals;
  final ThresholdDirection direction;
  final AlertLimit defaultThreshold;

  /// Rentang untuk grafik dan slider.
  final double minValue;
  final double maxValue;

  final String description;
  final String interpretation;
  final String limitation;

  /// true = nilai mentah ADC (belum dikalibrasi).
  final bool isRaw;

  /// false = sensor ini sendirian tidak boleh membuat status "Perlu Pemeriksaan".
  final bool canTriggerCheckAlone;

  String get unitCaption => isRaw ? '$unit (nilai mentah)' : unit;
}