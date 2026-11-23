/// Pemformat angka dan waktu berbahasa Indonesia (tanpa paket tambahan).
class Fmt {
  Fmt._();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// 31.5 -> "31,5". Nilai kosong -> "–".
  static String number(double? value, {int decimals = 0}) {
    if (value == null || value.isNaN) return '–';
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String clock(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static String hourMinute(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String date(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

  static String dateTime(DateTime t) => '${date(t)}, ${hourMinute(t)}';

  /// Durasi singkat: "12 detik lalu", "3 menit lalu", ...
  static String ago(Duration d) {
    final int s = d.inSeconds;
    if (s < 5) return 'baru saja';
    if (s < 60) return '$s detik lalu';
    if (s < 3600) return '${d.inMinutes} menit lalu';
    if (s < 86400) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }
}