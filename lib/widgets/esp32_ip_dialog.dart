import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/services/connection_tester.dart';
import 'package:monu/widgets/primary_button.dart';
import 'package:provider/provider.dart';

/// Membuka dialog / bottom sheet untuk memasukkan alamat IP ESP32 secara manual.
Future<void> showEsp32IpDialog(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _Esp32IpBottomSheet(),
  );
}

class _Esp32IpBottomSheet extends StatefulWidget {
  const _Esp32IpBottomSheet();

  @override
  State<_Esp32IpBottomSheet> createState() => _Esp32IpBottomSheetState();
}

class _Esp32IpBottomSheetState extends State<_Esp32IpBottomSheet> {
  late final TextEditingController _controller;
  bool _testing = false;
  ConnectionTestResult? _result;

  @override
  void initState() {
    super.initState();
    final SettingsProvider settings = context.read<SettingsProvider>();
    _controller = TextEditingController(text: settings.esp32Ip);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final String raw = _controller.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan IP Address ESP32 terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _testing = true;
      _result = null;
    });

    final ConnectionTestResult res = await ConnectionTester.testEsp32(ipAddress: raw);

    if (mounted) {
      setState(() {
        _testing = false;
        _result = res;
      });
    }
  }

  Future<void> _saveAndConnect() async {
    final String raw = _controller.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP Address tidak boleh kosong')),
      );
      return;
    }

    if (!ConnectionTester.isValidIp(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format IP tidak valid. Contoh yang benar: 192.168.1.100'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final SettingsProvider settings = context.read<SettingsProvider>();
    await settings.setEsp32Ip(raw);
    await settings.setConnectionMode('esp32');

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tersambung ke ESP32: $raw'),
          backgroundColor: AppColors.forest,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.fog, // Selaras dengan _AiSettingsSheet & tema aplikasi
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inkSoft.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header Judul & Icon
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.forest.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.forest.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: AppColors.forest,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alamat IP ESP32', style: AppText.headline),
                          const SizedBox(height: 2),
                          Text(
                            'Hubungkan aplikasi langsung ke alat via Wi-Fi',
                            style: AppText.caption.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Card Informasi Praktis (Kontras & Bersih)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.forest.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.forest),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cek alamat IP ESP32 di Serial Monitor Thonny/Arduino IDE saat alat menyala, lalu ketik atau pilih alamat di bawah ini.',
                          style: AppText.caption.copyWith(
                            color: AppColors.ink,
                            height: 1.45,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Label TextField
                Text('IP Address ESP32', style: AppText.label),
                const SizedBox(height: 8),

                // Input TextField Kontras Tinggi
                TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.title.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Contoh: 192.168.1.100',
                    hintStyle: AppText.caption.copyWith(
                      fontSize: 15,
                      color: AppColors.inkSoft.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.router_rounded, color: AppColors.forest, size: 22),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.inkSoft),
                            onPressed: () {
                              setState(() {
                                _controller.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.forest.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.forest.withValues(alpha: 0.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.forest, width: 2),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                // Tombol Cepat Pilihan Contoh IP
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _IpChip(
                      label: '192.168.1.100',
                      onTap: () {
                        setState(() => _controller.text = '192.168.1.100');
                      },
                    ),
                    _IpChip(
                      label: '192.168.4.1 (AP Mode)',
                      onTap: () {
                        setState(() => _controller.text = '192.168.4.1');
                      },
                    ),
                    _IpChip(
                      label: '192.168.43.100 (Hotspot)',
                      onTap: () {
                        setState(() => _controller.text = '192.168.43.100');
                      },
                    ),
                  ],
                ),

                // Feedback Hasil Tes Koneksi (Kontras Tinggi)
                if (_result != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_result!.outcome == TestOutcome.success
                              ? AppColors.safe
                              : (_result!.outcome == TestOutcome.warning
                                  ? AppColors.warning
                                  : AppColors.danger))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _result!.outcome == TestOutcome.success
                            ? AppColors.safe
                            : (_result!.outcome == TestOutcome.warning
                                ? AppColors.warning
                                : AppColors.danger),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _result!.outcome == TestOutcome.success
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _result!.outcome == TestOutcome.success
                              ? AppColors.safe
                              : (_result!.outcome == TestOutcome.warning
                                  ? AppColors.warning
                                  : AppColors.danger),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _result!.message,
                                style: AppText.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _result!.outcome == TestOutcome.success
                                      ? AppColors.forestDeep
                                      : (_result!.outcome == TestOutcome.warning
                                          ? AppColors.ink
                                          : AppColors.danger),
                                ),
                              ),
                              if (_result!.detail != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _result!.detail!,
                                  style: AppText.caption.copyWith(
                                    color: AppColors.inkSoft,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Tombol Aksi: Tes Koneksi & Simpan
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.forest,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 20),
                          label: Text(_testing ? 'Mengecek...' : 'Tes Koneksi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side: const BorderSide(color: AppColors.forest, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: PrimaryButton(
                        label: 'Simpan & Hubungkan',
                        height: 50,
                        fontSize: 14,
                        icon: Icons.check_rounded,
                        onPressed: _saveAndConnect,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IpChip extends StatelessWidget {
  const _IpChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.forestDeep,
        ),
      ),
      onPressed: onTap,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      side: BorderSide(color: AppColors.forest.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      shadowColor: Colors.black12,
    );
  }
}
