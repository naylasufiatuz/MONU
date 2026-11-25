import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_info.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/widgets/esp32_ip_dialog.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/status_chip.dart';
import 'package:provider/provider.dart';

/// Halaman Informasi: dokumentasi sistem DiHutan (MONU), spesifikasi pinout GPIO,
/// logika otomatisasi pompa & buzzer, endpoint API, serta panduan pemecahan masalah.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();

    return ForestBackground(
      strong: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kNavSpace),
          children: [
            const PageHeader(
              eyebrow: 'Panduan & Dokumentasi',
              title: 'Informasi',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Ringkasan Sistem DiHutan / MONU
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.forest,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.park_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${AppInfo.appName} (MONU IoT)', style: AppText.headline),
                                  Text(
                                    'Monitoring & Otomatisasi Miniatur Hutan',
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Sistem ini memantau kondisi lingkungan miniatur hutan secara real-time dan menjalankan otomatisasi penyiraman pompa air serta alarm buzzer darurat saat terdeteksi kekeringan, gas/asap berbahaya, maupun indikasi api pada probe thermocouple.',
                          style: AppText.bodySoft,
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: AppColors.forest.withValues(alpha: 0.12)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Status Node:', style: AppText.caption),
                            const SizedBox(width: 8),
                            StatusChip(
                              label: monitor.isOffline ? 'Offline' : 'Online',
                              color: monitor.isOffline ? AppColors.inkSoft : AppColors.safe,
                              dense: true,
                            ),
                            const Spacer(),
                            Flexible(
                              child: InkWell(
                                onTap: () => showEsp32IpDialog(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    settings.isEsp32Mode
                                        ? 'IP: ${settings.esp32Ip}'
                                        : monitor.modeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.label.copyWith(color: AppColors.forestDeep),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Spesifikasi Pinout GPIO Hardware Resmi (sesuai main.py)
                  Text('Spesifikasi Pinout GPIO ESP32', style: AppText.title),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Konfigurasi pin fisik mikrokontroler ESP32 (MicroPython main.py):',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 12),
                        const _PinRow(
                          sensor: 'Soil Moisture',
                          pin: 'GPIO 35',
                          type: 'ADC1_CH7',
                          desc: 'Sensor kelembapan tanah analog',
                        ),
                        const _PinRow(
                          sensor: 'DHT11',
                          pin: 'GPIO 4',
                          type: 'Digital 1-Wire',
                          desc: 'Suhu udara dan kelembapan kanopi',
                        ),
                        const _PinRow(
                          sensor: 'MQ-2 Gas/Asap',
                          pin: 'GPIO 34',
                          type: 'ADC1_CH6',
                          desc: 'Deteksi gas mudah terbakar dan asap',
                        ),
                        const _PinRow(
                          sensor: 'MAX6675 SCK',
                          pin: 'GPIO 18',
                          type: 'SPI Clock',
                          desc: 'Clock serial modul thermocouple Tipe-K',
                        ),
                        const _PinRow(
                          sensor: 'MAX6675 SO',
                          pin: 'GPIO 19',
                          type: 'SPI MISO',
                          desc: 'Jalur data keluar modul MAX6675',
                        ),
                        const _PinRow(
                          sensor: 'MAX6675 CS',
                          pin: 'GPIO 5',
                          type: 'SPI Chip Select',
                          desc: 'Chip select modul MAX6675 (Active-LOW)',
                        ),
                        const _PinRow(
                          sensor: 'Relay Pompa Air',
                          pin: 'GPIO 26',
                          type: 'Digital Output',
                          desc: 'Saklar driver pompa air (Active-LOW)',
                        ),
                        const _PinRow(
                          sensor: 'Buzzer Alarm',
                          pin: 'GPIO 27',
                          type: 'PWM Output',
                          desc: 'Sirine buzzer 2730 Hz / modulasi darurat',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Logika Otomatisasi & Alur Kerja Sistem (sesuai main.py)
                  Text('Logika Kerja & Otomatisasi', style: AppText.title),
                  const SizedBox(height: 8),
                  const _AutomationCard(
                    icon: Icons.grass,
                    title: '1. Otomatisasi Kelembapan Tanah',
                    condition: 'Kelembapan tanah turun hingga ≤ 30% (tanah kering).',
                    action: 'Pompa air menyala otomatis untuk menyiram dan berhenti saat mencapai target ≥ 65%. Buzzer tetap senyap (OFF).',
                  ),
                  const SizedBox(height: 10),
                  const _AutomationCard(
                    icon: Icons.air,
                    title: '2. Deteksi Dini Asap/Gas MQ-2',
                    condition: 'Nilai analog sensor MQ-2 mencapai ≥ 2500 ADC.',
                    action: 'Buzzer alarm berbunyi sebagai peringatan bahaya asap/gas, sedangkan pompa air tetap mati (OFF).',
                  ),
                  const SizedBox(height: 10),
                  const _AutomationCard(
                    icon: Icons.local_fire_department_outlined,
                    title: '3. Deteksi Panas / Api Thermocouple',
                    condition: 'Suhu probe ≥ 50 °C, ≤ 10 °C (probe terbalik saat dipanaskan), atau probe error/terputus (Fail-Safe).',
                    action: 'Pompa air dan sirine buzzer darurat langsung aktif bersamaan (melewati cooldown pompa) hingga kondisi kembali aman.',
                  ),
                  const SizedBox(height: 10),
                  const _AutomationCard(
                    icon: Icons.thermostat,
                    title: '4. Pemantauan Udara DHT11',
                    condition: 'Pembacaan suhu dan kelembapan udara kanopi secara berkala tiap 2.5 detik.',
                    action: 'Data ditampilkan di aplikasi untuk pemantauan iklim mikro dan pencatatan riwayat.',
                  ),

                  const SizedBox(height: 16),

                  // 4. Spesifikasi API & Jaringan
                  Text('Spesifikasi Komunikasi API', style: AppText.title),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/',
                          desc: 'Dashboard web HTML & kontrol manual',
                        ),
                        const SizedBox(height: 8),
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/api/status',
                          desc: 'JSON lengkap sensor, Wi-Fi, pompa & buzzer',
                        ),
                        const SizedBox(height: 8),
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/status',
                          desc: 'JSON ringkas status sistem PRD',
                        ),
                        const SizedBox(height: 8),
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/sensors',
                          desc: 'Data mentah pembacaan seluruh sensor',
                        ),
                        const SizedBox(height: 8),
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/pump',
                          desc: 'Kontrol manual pompa (?action=on/off/toggle)',
                        ),
                        const SizedBox(height: 8),
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/buzzer',
                          desc: 'Kontrol manual buzzer (?action=on/off/toggle)',
                        ),
                        const SizedBox(height: 8),
                        const _ApiEndpointRow(
                          method: 'GET',
                          path: '/health',
                          desc: 'Kesehatan node, uptime & sisa RAM',
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: AppColors.forest.withValues(alpha: 0.12)),
                        const SizedBox(height: 10),
                        Text(
                          'Aplikasi melakukan polling setiap 2 detik langsung ke IP ESP32 melalui port 80 pada jaringan Wi-Fi lokal yang sama, atau membaca data dari Supabase Cloud.',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Panduan Pemecahan Masalah
                  Text('Panduan Pemecahan Masalah', style: AppText.title),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _TroubleItem(
                          q: 'Status "Tidak Terhubung" pada aplikasi?',
                          a: 'Pastikan HP dan ESP32 terhubung ke Wi-Fi / Hotspot yang sama. Periksa alamat IP ESP32 pada Serial Monitor lalu masukkan lewat tombol Ubah IP atau Profil > Koneksi Perangkat.',
                        ),
                        _TroubleItem(
                          q: 'Wi-Fi ESP32 sering gagal connect atau Out of Memory?',
                          a: 'ESP32 hanya mendukung Wi-Fi 2.4 GHz (bukan 5 GHz). Jika muncul OSError WiFi Out of Memory di Thonny, tekan tombol EN/RST pada board ESP32 lalu jalankan ulang main.py.',
                        ),
                        _TroubleItem(
                          q: 'Suhu thermocouple malah turun saat dibakar / memicu error?',
                          a: 'Periksa sambungan kabel T+ dan T- pada terminal baut modul MAX6675. Jika suhu turun ke ≤ 10 °C saat dipanaskan, kabel probe terpasang terbalik; tukar kedua kabel tersebut.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Footer Info Aplikasi
                  Center(
                    child: Column(
                      children: [
                        Text('${AppInfo.appName} IoT App • Versi 1.0.0', style: AppText.caption),
                        const SizedBox(height: 4),
                        Text(
                          'Miniatur Hutan • ESP32 MicroPython & Flutter',
                          style: AppText.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.sensor,
    required this.pin,
    required this.type,
    required this.desc,
    this.isLast = false,
  });

  final String sensor;
  final String pin;
  final String type;
  final String desc;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pin,
                  style: AppText.label.copyWith(
                    color: AppColors.forestDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(sensor, style: AppText.label.copyWith(fontSize: 13.5)),
                        const SizedBox(width: 6),
                        Text('($type)', style: AppText.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(desc, style: AppText.caption.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AppColors.forest.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({
    required this.icon,
    required this.title,
    required this.condition,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String condition;
  final String action;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.forest, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: AppText.caption.copyWith(fontSize: 12),
                    children: [
                      const TextSpan(
                        text: 'Kondisi: ',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                      TextSpan(text: condition),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: AppText.caption.copyWith(fontSize: 12),
                    children: [
                      const TextSpan(
                        text: 'Tindakan: ',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.forestDeep),
                      ),
                      TextSpan(text: action),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiEndpointRow extends StatelessWidget {
  const _ApiEndpointRow({
    required this.method,
    required this.path,
    required this.desc,
  });

  final String method;
  final String path;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.safe.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            method,
            style: AppText.label.copyWith(
              color: AppColors.safe,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(path, style: AppText.label.copyWith(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            desc,
            style: AppText.caption.copyWith(fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TroubleItem extends StatelessWidget {
  const _TroubleItem({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: AppColors.forest),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  q,
                  style: AppText.label.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              a,
              style: AppText.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
