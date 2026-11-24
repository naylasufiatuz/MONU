import 'package:flutter/material.dart';
import 'package:monu/models/sensor_spec.dart';

/// SATU-SATUNYA tempat daftar sensor.
/// Menambah/menghapus sensor cukup mengubah daftar [all] di bawah.
///
/// Nilai ambang di sini hanya CONTOH AWAL. Sesuai PRD, ambang final harus
/// ditentukan setelah kalibrasi dan pengujian, lalu diatur dari app
/// (Profil > Batas Peringatan).
class SensorConfig {
  SensorConfig._();

  static const List<SensorSpec> all = [
    SensorSpec(
      id: 'temperature',
      name: 'Suhu Udara',
      shortName: 'Suhu',
      unit: '°C',
      icon: Icons.thermostat,
      decimals: 1,
      direction: ThresholdDirection.high,
      defaultThreshold: AlertLimit(warning: 35, check: 40),
      minValue: 0,
      maxValue: 60,
      description: 'Sensor DHT11 mengukur suhu udara di sekitar sensor.',
      interpretation:
          'Suhu yang naik menunjukkan udara di sekitar sensor menghangat.',
      limitation:
          'DHT11 cocok untuk demonstrasi dasar: rentang sekitar 0–50 °C dengan ketelitian sekitar ±2 °C.',
    ),
    SensorSpec(
      id: 'humidity',
      name: 'Kelembapan Udara',
      shortName: 'Kelembapan',
      unit: '%RH',
      icon: Icons.water_drop_outlined,
      decimals: 0,
      direction: ThresholdDirection.low,
      defaultThreshold: AlertLimit(warning: 40, check: 30),
      minValue: 0,
      maxValue: 100,
      description:
          'Sensor DHT11 mengukur kelembapan relatif udara (%RH) di sekitar sensor.',
      interpretation: 'Nilai yang rendah berarti udara relatif lebih kering.',
      limitation:
          'DHT11 membaca sekitar 20–90 %RH dengan ketelitian sekitar ±5 %RH.',
    ),
    SensorSpec(
      id: 'soilMoistureRaw',
      name: 'Kelembapan Tanah',
      shortName: 'Tanah',
      unit: 'ADC',
      icon: Icons.grass,
      decimals: 0,
      // Umumnya sensor kapasitif: nilai ADC lebih TINGGI saat tanah lebih kering.
      // Kalau modulmu kebalikannya, ubah direction menjadi ThresholdDirection.low
      // dan tukar nilai ambangnya.
      direction: ThresholdDirection.high,
      defaultThreshold: AlertLimit(warning: 2800, check: 3300),
      minValue: 0,
      maxValue: 4095,
      isRaw: true,
      description:
          'Sensor kapasitif membaca kelembapan media tanah di sekitar probe.',
      interpretation:
          'Pada sensor kapasitif, nilai ADC yang lebih tinggi umumnya berarti tanah lebih kering. Pastikan arahnya saat kalibrasi.',
      limitation:
          'Nilai mentah belum setara kadar air. Kalibrasi pada media yang sama. Hanya mewakili titik probe, bukan seluruh miniatur.',
    ),
    SensorSpec(
      id: 'mq2Raw',
      name: 'Gas / Asap (MQ-2)',
      shortName: 'MQ-2',
      unit: 'ADC',
      icon: Icons.air,
      decimals: 0,
      direction: ThresholdDirection.high,
      defaultThreshold: AlertLimit(warning: 1500, check: 2500),
      minValue: 0,
      maxValue: 4095,
      isRaw: true,
      canTriggerCheckAlone: false,
      description:
          'Sensor MQ-2 merespons sejumlah gas mudah terbakar dan asap.',
      interpretation:
          'Nilai yang naik berarti respons sensor naik. Ini bukan konsentrasi ppm.',
      limitation:
          'Perlu pemanasan awal dan kalibrasi, serta bisa merespons zat lain. Bukan bukti pasti kebakaran.',
    ),
    SensorSpec(
      id: 'thermocouple',
      name: 'Thermocouple (MAX6675)',
      shortName: 'Thermo',
      unit: '°C',
      icon: Icons.thermostat_outlined,
      decimals: 1,
      direction: ThresholdDirection.high,
      defaultThreshold: AlertLimit(warning: 50, check: 70),
      minValue: 0,
      maxValue: 1024,
      description:
          'Sensor thermocouple MAX6675 mengukur suhu pada titik kontak probe tipe K.',
      interpretation:
          'Suhu tinggi menunjukkan kenaikan panas intensif pada titik pengukuran.',
      limitation:
          'Mengukur titik kontak thermocouple, bukan suhu udara seluruh ruangan.',
    ),
  ];

  static SensorSpec byId(String id) => all.firstWhere((s) => s.id == id);
}