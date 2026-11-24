import 'package:monu/config/iot_config.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/services/assistant_context.dart';
import 'package:monu/services/assistant_models.dart';

/// Penjawab berbasis aturan (tanpa AI dan tanpa internet).
/// Dipakai saat belum ada kunci Gemini, atau saat Gemini gagal.
class LocalEngine implements AssistantEngine {
  @override
  String get label => 'Mode Contoh';

  static const List<String> _knowledgeWords = [
    'arti', 'apa itu', 'fungsi', 'cara kerja', 'akurat', 'akurasi',
    'batasan', 'maksud', 'penjelasan',
  ];

  static const List<String> _actionWords = [
    'harus', 'tindakan', 'saran', 'periksa', 'solusi', 'apa yang',
    'bagaimana cara', 'langkah',
  ];

  @override
  Future<String> reply({
    required List<ChatMessage> history,
    required AssistantData data,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final String q = history.isEmpty ? '' : history.last.text.toLowerCase();
    return _answer(q, history, data);
  }

  String _answer(String q, List<ChatMessage> history, AssistantData d) {
    if (RegExp(r'^(halo|hai|hi|hello|hey|selamat|pagi|siang|sore|malam)\b')
        .hasMatch(q.trim())) {
      return _greeting(d);
    }
    if (_has(q, ['terima kasih', 'makasih', 'thanks', 'thx'])) {
      return 'Sama-sama! Kalau ada yang mau ditanyakan lagi soal sensor atau peringatan, tanya saja ya.';
    }
    if (_has(q, ['siapa kamu', 'kamu siapa', 'bisa apa', 'fitur apa', 'bantu apa'])) {
      return _about();
    }
    if (RegExp(r'\b(api|kebakaran|terbakar|membakar)\b').hasMatch(q)) {
      return _fire(d);
    }
    if (_has(q, ['monu', 'sistem ini', 'aplikasi ini', 'proyek ini', 'latar belakang', 'tujuan'])) {
      return _monuSystem(d);
    }
    if (_has(q, ['relay', 'pompa', 'aktuator', 'nyiram', 'menyiram'])) {
      return _relayPump(d);
    }
    if (_has(q, ['thermo', 'thermocouple', 'max6675', 'k-type'])) {
      return _thermocouple(d);
    }
    if (_has(q, ['esp32', 'alat', 'hardware', 'mikrokontroler'])) {
      return _esp32(d);
    }
    if (_has(q, ['offline', 'online', 'putus', 'koneksi', 'wifi', 'wi-fi',
      'terhubung', 'tersambung',
    ])) {
      return _connection(d);
    }

    final SensorSpec? direct = _sensorIn(q);

    if (_has(q, ['peringatan', 'alert', 'notifikasi']) ||
        (q.contains('kenapa') && _has(q, ['status', 'waspada', 'periksa']))) {
      return _alerts(d, direct);
    }

    if (direct != null) {
      if (_has(q, _knowledgeWords)) return _knowledge(d, direct);
      if (q.contains('kalibrasi')) return _calibration(direct);
      if (_has(q, _actionWords)) return _action(d, direct);
      return _sensor(d, d.factsOf(direct.id));
    }

    if (_has(q, ['ambang', 'batas', 'threshold'])) return _thresholds(d);
    if (_has(q, ['tren', 'naik', 'turun', 'riwayat', 'grafik'])) {
      return _trends(d);
    }
    if (q.contains('kalibrasi')) return _calibrationGeneral();
    if (_has(q, _actionWords)) return _action(d, null);
    if (_has(q, [
      'kondisi', 'status', 'ringkas', 'rangkum', 'sekarang', 'bagaimana',
      'gimana', 'aman', 'normal', 'laporan',
    ])) {
      return _summary(d);
    }

    final SensorSpec? previous = _lastSensor(history);
    if (previous != null && q.length < 40) {
      if (_has(q, _knowledgeWords)) return _knowledge(d, previous);
      return _sensor(d, d.factsOf(previous.id));
    }
    return _fallback();
  }

  // ---------------------------------------------------------------------
  // Pengenal topik
  // ---------------------------------------------------------------------

  bool _has(String q, List<String> words) => words.any(q.contains);

  SensorSpec? _sensorIn(String q) {
    if (_has(q, ['tanah', 'soil', 'probe', 'siram'])) {
      return SensorConfig.byId('soilMoistureRaw');
    }
    if (_has(q, ['mq', 'asap', 'gas'])) return SensorConfig.byId('mq2Raw');
    if (_has(q, [
      'suhu', 'temperatur', 'temperature', 'panas', 'dingin', 'celsius', 'dht',
    ])) {
      return SensorConfig.byId('temperature');
    }
    if (_has(q, [
      'kelembapan', 'kelembaban', 'lembap', 'lembab', 'humidity', '%rh',
    ])) {
      return SensorConfig.byId('humidity');
    }
    return null;
  }

  SensorSpec? _lastSensor(List<ChatMessage> history) {
    for (int i = history.length - 2; i >= 0; i--) {
      if (history[i].role != ChatRole.user) continue;
      final SensorSpec? s = _sensorIn(history[i].text.toLowerCase());
      if (s != null) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Jawaban
  // ---------------------------------------------------------------------

  String _greeting(AssistantData d) {
    final String state = d.hasData
        ? 'Sekarang status hutan miniaturmu **${d.status.label}**.'
        : 'Aku belum menerima data dari perangkat.';
    return 'Halo! Aku Asisten MONU. $state\n\nMau kuringkas kondisi sensor, jelaskan peringatan, atau arti tiap sensor?';
  }

  String _about() {
    return 'Aku Asisten MONU. Aku bisa:\n'
        '- meringkas **kondisi dan status** sekarang\n'
        '- menjelaskan **nilai, tren, dan batas** tiap sensor\n'
        '- menjelaskan **peringatan** dan apa yang perlu diperiksa\n'
        '- menjelaskan **arti sensor** (DHT11, tanah, MQ-2)\n\n'
        'Saat ini aku menjawab dengan Mode Contoh (aturan otomatis). Pasang kunci Gemini di pengaturan AI untuk jawaban yang lebih luwes.';
  }

  String _noData(AssistantData d) {
    final String err = d.connectionError == null ? '' : '\n\nMasalahnya: ${d.connectionError}';
    return 'Aku belum menerima data dari perangkat, jadi belum bisa membaca kondisi sensor.$err\n\nCek bagian Pengaturan Koneksi IoT dan pastikan ESP32 menyala.';
  }

  String _summary(AssistantData d) {
    if (!d.hasData) return _noData(d);
    final StringBuffer b = StringBuffer();
    b.writeln('**Status: ${d.status.label}.** ${d.status.description}');
    b.writeln();
    for (final SensorFacts s in d.sensors) {
      b.writeln('- **${s.spec.shortName}**: ${s.valueText} (${s.level.label})');
    }
    b.writeln();
    if (d.activeAlerts.isNotEmpty) {
      b.writeln('Ada ${d.activeAlerts.length} peringatan aktif. Tanya "kenapa waspada?" untuk penjelasannya.');
      b.writeln();
    }
    b.write(
      d.offline
          ? 'Data terakhir diterima ${d.sinceText}, jadi ini bukan data terbaru.'
          : 'Data diperbarui ${d.sinceText}.',
    );
    return b.toString();
  }

  String _sensor(AssistantData d, SensorFacts s) {
    if (!d.hasData) return _noData(d);
    final SensorSpec spec = s.spec;

    if (s.value == null) {
      return '**${spec.name}** sedang **tidak terbaca**. Aku tidak mengisinya dengan angka perkiraan.\n\nCoba cek kabel, pin, dan catu daya sensor ini. Selama ada sensor yang gagal, status tidak akan dianggap Normal.';
    }

    final String levelText = switch (s.level) {
      SensorLevel.normal => 'masih **normal** (batas waspada ${s.warningText})',
      SensorLevel.warning => '**waspada**: sudah melewati ambang ${s.warningText}',
      SensorLevel.check => '**perlu pemeriksaan**: sudah melewati ambang ${s.checkText}',
      SensorLevel.unavailable => 'tidak tersedia',
    };

    final StringBuffer b = StringBuffer();
    b.writeln('**${spec.name}: ${s.valueText}**${spec.isRaw ? ' (nilai mentah)' : ''}, $levelText.');
    b.writeln();
    b.writeln('- Tren: ${s.trend}.');
    if (s.hourText.isNotEmpty) b.writeln('- Satu jam terakhir: ${s.hourText}.');
    if (spec.id == 'soilMoistureRaw' && d.soilPercent != null) {
      b.writeln('- Perkiraan: sekitar ${d.soilPercent!.toStringAsFixed(0)} % (kalibrasi contoh).');
    }
    b.writeln('- ${spec.interpretation}');

    if (d.offline) {
      b.writeln();
      b.write('Catatan: perangkat sedang offline, jadi ini data lama (${d.sinceText}).');
    } else if (!spec.canTriggerCheckAlone && s.level.isAlert) {
      b.writeln();
      b.write('MQ-2 hanya indikator tambahan, bukan bukti kebakaran.');
    }
    return b.toString().trim();
  }

  String _knowledge(AssistantData d, SensorSpec spec) {
    final SensorFacts s = d.factsOf(spec.id);
    final String now = d.hasData && s.value != null
        ? '\n\nNilai sekarang: **${s.valueText}** (${s.level.label}).'
        : '';
    return '**${spec.name}**\n${spec.description}\n\n- Cara membaca: ${spec.interpretation}\n- Batasan: ${spec.limitation}$now';
  }

  String _calibration(SensorSpec spec) {
    final String how = switch (spec.id) {
      'soilMoistureRaw' =>
        'Catat nilai ADC saat probe di tanah yang benar-benar kering dan saat basah, pada media dan posisi yang sama. Dua angka itu jadi rentang kalibrasi.',
      'mq2Raw' =>
        'Biarkan MQ-2 menyala dan menjalani pemanasan, lalu catat nilai dasar di udara bersih. Ambang ditentukan dari nilai dasar itu, bukan dari angka acak.',
      _ =>
        'Bandingkan pembacaan dengan alat ukur pembanding pada kondisi yang sama, lalu catat selisihnya.',
    };
    return 'Kalibrasi **${spec.name}**: $how\n\nSetelah itu atur ambang di halaman Profil sesuai hasil pengujianmu.';
  }

  String _calibrationGeneral() {
    return 'Kalibrasi artinya mencocokkan pembacaan sensor dengan kondisi yang diketahui.\n'
        '- **DHT11**: bandingkan dengan termometer dan higrometer.\n'
        '- **Tanah**: catat nilai ADC saat kering dan saat basah.\n'
        '- **MQ-2**: catat nilai dasar di udara bersih setelah pemanasan.\n\n'
        'Hasilnya dipakai untuk menentukan ambang peringatan.';
  }

  String _thresholds(AssistantData d) {
    final StringBuffer b = StringBuffer('Batas peringatan saat ini:\n');
    for (final SensorFacts s in d.sensors) {
      b.writeln('- **${s.spec.shortName}**: waspada ${s.warningText}, pemeriksaan ${s.checkText}');
    }
    b.write('\nNilai awal hanya contoh. Ubah di halaman Profil setelah kalibrasi dan pengujian.');
    return b.toString();
  }

  String _trends(AssistantData d) {
    if (!d.hasData) return _noData(d);
    final StringBuffer b = StringBuffer('Tren terbaru:\n');
    for (final SensorFacts s in d.sensors) {
      b.writeln('- **${s.spec.shortName}**: ${s.trend}');
    }
    b.write('\nGrafik lengkap ada di halaman Detail Sensor.');
    return b.toString();
  }

  String _alerts(AssistantData d, SensorSpec? focus) {
    if (!d.hasData) return _noData(d);

    List<AlertEvent> active = d.activeAlerts;
    if (focus != null) {
      active = active.where((a) => a.sensorId == focus.id).toList();
      if (active.isEmpty) return _sensor(d, d.factsOf(focus.id));
    }

    if (active.isEmpty) {
      final StringBuffer b = StringBuffer(
        'Tidak ada peringatan aktif. Status sekarang **${d.status.label}**.',
      );
      if (d.recentAlerts.isNotEmpty) {
        b.writeln();
        b.writeln();
        b.writeln('Peringatan yang baru saja pulih:');
        for (final AlertEvent a in d.recentAlerts.take(3)) {
          b.writeln('- ${a.title}');
        }
      }
      return b.toString().trim();
    }

    final StringBuffer b = StringBuffer();
    if (focus == null) {
      b.writeln('Status **${d.status.label}** karena ada ${active.length} peringatan aktif:');
      b.writeln();
    }
    for (final AlertEvent a in active) {
      b.writeln('- **${a.title}**: ${a.message}');
      b.writeln('  Saran: ${_tip(a)}');
    }
    b.writeln();
    b.write('Ingat, peringatan hanya indikator untuk memeriksa prototipe, bukan konfirmasi kebakaran.');
    return b.toString();
  }

  String _tip(AlertEvent a) {
    switch (a.kind) {
      case AlertKind.deviceOffline:
        return 'cek daya dan Wi-Fi ESP32.';
      case AlertKind.deviceOnline:
        return 'perangkat sudah terhubung kembali dan siap dimonitor.';
      case AlertKind.wateringStarted:
        return 'pompa air sedang aktif menyiram tanah.';
      case AlertKind.wateringFinished:
        return 'penyiraman telah selesai dan pompa kembali mati.';
      case AlertKind.drySoil:
        return 'cek posisi probe kelembapan tanah dan ketersediaan air penyiraman.';
      case AlertKind.sensorFailure:
        return 'cek kabel, pin, dan catu daya sensor itu.';
      case AlertKind.threshold:
        return switch (a.sensorId) {
          'temperature' =>
            'pastikan sensor tidak terkena panas langsung, lalu bandingkan dengan termometer lain.',
          'humidity' =>
            'udara relatif kering. Bandingkan dengan alat lain dan cek apakah sensor dekat sumber panas atau pendingin.',
          'soilMoistureRaw' =>
            'tanah relatif kering di titik probe. Cek posisi probe dan kalibrasi pada media yang sama.',
          'mq2Raw' =>
            'pastikan MQ-2 sudah menjalani pemanasan, cek ventilasi dan sumber gas atau asap lain di sekitarnya (misalnya parfum atau spirtus). Jangan menguji dengan api.',
          'thermocouple' =>
            'suhu thermocouple tinggi. Periksa titik panas dan pastikan probe thermocouple terpasang kuat.',
          _ => 'periksa sensor dan sambungannya.',
        };
    }
  }

  String _action(AssistantData d, SensorSpec? focus) {
    if (d.hasData && d.offline) return _connection(d);
    if (!d.hasData) return _noData(d);

    List<AlertEvent> active = d.activeAlerts;
    if (focus != null) {
      active = active.where((a) => a.sensorId == focus.id).toList();
    }
    if (active.isNotEmpty) return _alerts(d, focus);

    return 'Saat ini tidak ada yang mendesak: status **${d.status.label}**.\n\nUntuk rutin:\n'
        '- pastikan kabel dan catu daya terpasang kuat\n'
        '- jaga sensor tetap kering dan jauh dari panas langsung\n'
        '- catat nilai dasar MQ-2 di udara bersih\n'
        '- tinjau ulang ambang setelah kalibrasi';
  }

  String _connection(AssistantData d) {
    if (!d.hasData) return _noData(d);
    if (!d.offline) {
      return 'Perangkat **Online**. Data baru terakhir masuk ${d.sinceText}. Sumber data: ${d.modeLabel}.';
    }
    return 'Perangkat **Offline**: tidak ada data baru lebih dari ${IotConfig.offlineAfter.inSeconds} detik (terakhir ${d.sinceText}). Nilai yang tampil adalah data lama.\n\nYang bisa dicek:\n'
        '- daya ESP32 dan kabel USB\n'
        '- Wi-Fi: apakah ESP32 terhubung ke jaringan\n'
        '- ID perangkat dan URL database di Pengaturan Koneksi IoT\n'
        '- Rules database (izinkan baca dan tulis)';
  }

  String _fire(AssistantData d) {
    final StringBuffer b = StringBuffer();
    b.writeln('Aku tidak bisa memastikan ada atau tidaknya kebakaran. MONU hanya indikator untuk memeriksa kondisi prototipe, dan MQ-2 bisa merespons zat lain.');
    if (d.hasData) {
      final SensorFacts t = d.factsOf('temperature');
      final SensorFacts g = d.factsOf('mq2Raw');
      b.writeln();
      b.writeln('Yang terbaca sekarang: status **${d.status.label}**, suhu ${t.valueText}, MQ-2 ${g.valueText}.');
    }
    b.writeln();
    b.write('Kalau di lapangan ada tanda kebakaran nyata, segera menjauh dan hubungi pemadam kebakaran (113) atau 112. Jangan menguji sensor dengan api atau asap.');
    return b.toString();
  }

  String _monuSystem(AssistantData d) {
    return '**MONU (Monitoring Hutan)** adalah sistem pemantau miniatur hutan berbasis Internet of Things (IoT) yang ditenagai mikrokontroler **ESP32**.\n\n'
        'Fungsi utama MONU:\n'
        '- **DHT11**: Memantau suhu udara dan kelembapan di sekitar miniatur hutan.\n'
        '- **Soil Moisture**: Memeriksa kebasahan tanah untuk mencegah kekeringan.\n'
        '- **MQ-2**: Mendeteksi asap dan gas mudah terbakar sebagai peringatan dini.\n'
        '- **MAX6675 (Thermocouple)**: Mengukur suhu ekstrem tahan panas.\n'
        '- **Relay**: Mengontrol pompa air untuk penyiraman otomatis.\n'
        '- **Supabase Cloud**: Mengirim telemetri secara realtime ke database PostgreSQL.';
  }

  String _relayPump(AssistantData d) {
    return '**Pompa Air & Relay (GPIO 19)**:\n'
        '- Relay berfungsi sebagai saklar elektronik untuk menghidupkan/mematikan pompa penyiram air miniatur hutan.\n'
        '- Pompa akan aktif jika tanah terdeteksi kering atau ada instruksi penyiraman manual dari aplikasi/sistem.\n'
        '- Status pompa dapat dipantau di dashboard Web atau aplikasi.';
  }

  String _thermocouple(AssistantData d) {
    return '**Sensor Thermocouple MAX6675 (K-Type)**:\n'
        '- Sensor ini menggunakan probe logam tahan api yang dapat mengukur suhu tinggi ekstrem (hingga ratusan derajat Celsius).\n'
        '- Digunakan untuk memantau titik panas atau bara api pada simulasi kebakaran miniatur hutan.';
  }

  String _esp32(AssistantData d) {
    return '**Mikrokontroler ESP32 (monu-node-1)**:\n'
        '- Otak pengendali dari sistem MONU. ESP32 membaca data dari seluruh sensor lalu mengirimkannya ke cloud Supabase atau via HTTP REST port 80.\n'
        '- Menggunakan sistem koneksi otomatis DHCP (tanpa perlu IP statis).\n'
        '- Anda dapat mengganti atau memasukkan IP ESP32 lewat tombol "Ubah IP" di Ringkasan.';
  }

  String _fallback() {
    return 'Pertanyaanmu menarik! Sebagai Asisten MONU, aku menguasai topik seputar pemantauan hutan miniatur dan sensor IoT.\n\n'
        'Kamu bisa menanyakan hal-hal seperti:\n'
        '- **"Ringkas kondisi hutan sekarang"**\n'
        '- **"Berapa suhu dan kelembapan ideal?"**\n'
        '- **"Apa fungsi sensor MQ-2 dan tanah?"**\n'
        '- **"Ceritakan tentang sistem MONU dan ESP32"**\n'
        '- **"Kapan pompa air harus dinyalakan?"**\n\n'
        '*Catatan:* Jika ingin mengobrol bebas di luar topik MONU, pastikan kunci Gemini aktif dan valid di Pengaturan AI.';
  }
}