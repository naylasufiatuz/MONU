import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/providers/auth_provider.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/services/connection_tester.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final NavigatorState navigator = Navigator.of(context);

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Kamu bisa masuk lagi kapan saja.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await auth.signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final String initial =
        auth.name.isEmpty ? '?' : auth.name.substring(0, 1).toUpperCase();

    return Scaffold(
      body: ForestBackground(
        strong: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(
                title: 'Profil & Pengaturan',
                leading: CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Kartu Pengguna
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.forest,
                            ),
                            child: Text(
                              initial,
                              style: AppText.headline.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.name, style: AppText.title),
                                Text(
                                  auth.email.isEmpty ? '-' : auth.email,
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bagian Koneksi Perangkat ESP32
                    const _DeviceConnectionSection(),

                    const SizedBox(height: 16),

                    // Kartu Pilihan Sumber Data
                    GlassCard(
                      showShadow: false,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.settings_ethernet,
                                color: AppColors.inkSoft,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Mode Sumber Data', style: AppText.body),
                              ),
                              Text(monitor.modeLabel, style: AppText.label),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('ESP32 Langsung'),
                                selected: settings.isEsp32Mode,
                                onSelected: (val) {
                                  if (val) settings.setConnectionMode('esp32');
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Mode Demo'),
                                selected: settings.connectionMode == 'mock',
                                onSelected: (val) {
                                  if (val) settings.setConnectionMode('mock');
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Firebase'),
                                selected: settings.connectionMode == 'firebase',
                                onSelected: (val) {
                                  if (val) settings.setConnectionMode('firebase');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('Keluar Akun'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bagian "Koneksi Perangkat" untuk mengatur IP Address ESP32 dan melakukan tes koneksi
class _DeviceConnectionSection extends StatefulWidget {
  const _DeviceConnectionSection();

  @override
  State<_DeviceConnectionSection> createState() => _DeviceConnectionSectionState();
}

class _DeviceConnectionSectionState extends State<_DeviceConnectionSection> {
  late final TextEditingController _ipController;
  bool _isTesting = false;
  ConnectionTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    final SettingsProvider settings = context.read<SettingsProvider>();
    _ipController = TextEditingController(text: settings.esp32Ip);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _saveIp() async {
    final String input = _ipController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP Address tidak boleh kosong')),
      );
      return;
    }

    if (!ConnectionTester.isValidIp(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format IP Address tidak valid. Contoh: 192.168.1.100'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final SettingsProvider settings = context.read<SettingsProvider>();
    await settings.setEsp32Ip(input);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IP Address ESP32 berhasil disimpan: $input'),
          backgroundColor: AppColors.forest,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final String ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan IP Address terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final ConnectionTestResult result =
        await ConnectionTester.testEsp32(ipAddress: ip);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final MonitorProvider monitor = context.watch<MonitorProvider>();

    // Menentukan status koneksi aktual
    final bool isActuallyConnected;
    final String statusText;
    final Color statusColor;
    final IconData statusIcon;
    final String? detailText;

    if (_testResult != null) {
      // Hasil dari tombol "Tes Koneksi"
      isActuallyConnected = _testResult!.outcome == TestOutcome.success;
      statusText = _testResult!.message;
      statusColor = _testResult!.outcome == TestOutcome.success
          ? AppColors.safe
          : (_testResult!.outcome == TestOutcome.warning
              ? AppColors.warning
              : AppColors.danger);
      statusIcon = isActuallyConnected
          ? Icons.check_circle_outline
          : Icons.cancel_outlined;
      detailText = _testResult!.detail;
    } else {
      // Berdasarkan polling real-time aplikasi
      if (settings.isEsp32Mode) {
        final bool offline = monitor.isOffline;
        isActuallyConnected = !offline;
        statusText = isActuallyConnected ? 'Terhubung' : 'Tidak Terhubung';
        statusColor = isActuallyConnected ? AppColors.safe : AppColors.inkSoft;
        statusIcon = isActuallyConnected
            ? Icons.check_circle_outline
            : Icons.wifi_off_rounded;
        detailText = monitor.connectionError ??
            (isActuallyConnected
                ? 'Terhubung secara real-time ke ${monitor.deviceName}'
                : 'Belum ada respons dari ESP32 (${settings.esp32Ip})');
      } else {
        isActuallyConnected = false;
        statusText = 'Tidak Terhubung (Mode Demo aktif)';
        statusColor = AppColors.inkSoft;
        statusIcon = Icons.info_outline;
        detailText = 'Tekan "Tes Koneksi" atau "Simpan IP" untuk beralih ke ESP32.';
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.router_rounded,
                  color: AppColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Koneksi Perangkat', style: AppText.title),
                    Text(
                      'Komunikasi langsung ke ESP32 via HTTP REST',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Informasi IP yang sedang digunakan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.forest),
                const SizedBox(width: 8),
                Text('IP yang digunakan: ', style: AppText.caption),
                Expanded(
                  child: Text(
                    settings.esp32Ip.isEmpty ? 'Belum diatur' : settings.esp32Ip,
                    style: AppText.label.copyWith(
                      color: AppColors.forestDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Input IP Address
          Text('IP Address ESP32:', style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.url,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: 'Contoh: 192.168.1.100',
              prefixIcon: const Icon(Icons.language, color: AppColors.inkSoft),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.forest.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.forest.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.forest, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tombol Simpan IP & Tes Koneksi
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveIp,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan IP'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(_isTesting ? 'Menguji...' : 'Tes Koneksi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Indikator Status Koneksi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status: $statusText',
                        style: AppText.label.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (detailText != null && detailText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      detailText,
                      style: AppText.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
