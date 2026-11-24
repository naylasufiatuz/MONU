import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:monu/services/assistant_context.dart';
import 'package:monu/services/assistant_models.dart';
import 'package:monu/services/assistant_prompt.dart';

class _Turn {
  _Turn(this.role, this.text);

  final String role;
  String text;
}

/// Memanggil Gemini lewat REST (generateContent).
class GeminiEngine implements AssistantEngine {
  GeminiEngine({required this.apiKey, required this.model});

  final String apiKey;
  final String model;

  /// Alias model Gemini default (stabil dan cepat).
  static const String defaultModel = 'gemini-1.5-flash';

  @override
  String get label => 'Gemini';

  @override
  Future<String> reply({
    required List<ChatMessage> history,
    required AssistantData data,
  }) {
    return _generate(
      system: buildSystemPrompt(data),
      contents: _contents(history),
    );
  }

  /// Dipakai tombol "Tes" di pengaturan AI.
  static Future<void> test({
    required String apiKey,
    required String model,
  }) async {
    await GeminiEngine(apiKey: apiKey, model: model)._generate(
      system: 'Balas hanya dengan satu kata: OK',
      contents: <Map<String, Object>>[
        <String, Object>{
          'role': 'user',
          'parts': <Map<String, String>>[
            <String, String>{'text': 'Tes koneksi'},
          ],
        },
      ],
    );
  }

  /// Gabungkan pesan beruntun yang peran sama, dan pastikan dimulai dari user.
  List<Map<String, Object>> _contents(List<ChatMessage> history) {
    final List<_Turn> turns = <_Turn>[];
    for (final ChatMessage m in history) {
      final String role = m.role == ChatRole.user ? 'user' : 'model';
      if (turns.isNotEmpty && turns.last.role == role) {
        turns.last.text = '${turns.last.text}\n${m.text}';
      } else {
        turns.add(_Turn(role, m.text));
      }
    }
    while (turns.isNotEmpty && turns.first.role != 'user') {
      turns.removeAt(0);
    }
    return <Map<String, Object>>[
      for (final _Turn t in turns)
        <String, Object>{
          'role': t.role,
          'parts': <Map<String, String>>[
            <String, String>{'text': t.text},
          ],
        },
    ];
  }

  Future<String> _generate({
    required String system,
    required List<Map<String, Object>> contents,
  }) async {
    final String key = apiKey.trim();
    if (key.isEmpty) {
      throw const AssistantException('Kunci API belum diisi.');
    }
    final String modelName = model.trim().isEmpty ? defaultModel : model.trim();
    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$key',
    );

    // Catatan: sengaja tidak mengirim "temperature" dan parameter sampling lain,
    // karena model Gemini terbaru tidak lagi memakainya.
    final String body = jsonEncode(<String, Object>{
      'systemInstruction': <String, Object>{
        'parts': <Map<String, String>>[
          <String, String>{'text': system},
        ],
      },
      'contents': contents,
    });

    final http.Response res = await _post(uri, key, body);
    final dynamic json = _decode(res.body);

    if (res.statusCode != 200) {
      throw AssistantException(_httpError(res.statusCode, json, modelName));
    }
    if (json is! Map) {
      throw const AssistantException('Balasan Gemini tidak bisa dibaca.');
    }

    final dynamic candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final dynamic feedback = json['promptFeedback'];
      final dynamic reason = feedback is Map ? feedback['blockReason'] : null;
      throw AssistantException(
        reason != null
            ? 'Gemini menolak menjawab pertanyaan ini ($reason).'
            : 'Gemini tidak memberi jawaban. Coba pertanyaan lain.',
      );
    }

    final dynamic content = candidates.first['content'];
    final StringBuffer text = StringBuffer();
    if (content is Map && content['parts'] is List) {
      for (final dynamic p in content['parts'] as List<dynamic>) {
        if (p is Map && p['text'] is String && p['thought'] != true) {
          text.write(p['text']);
        }
      }
    }

    final String out = text.toString().trim();
    if (out.isEmpty) {
      throw const AssistantException(
        'Jawaban Gemini kosong. Coba tanyakan dengan kalimat lain.',
      );
    }
    return out;
  }

  Future<http.Response> _post(Uri uri, String key, String body) async {
    try {
      return await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const AssistantException('Gemini terlalu lama menjawab. Coba lagi.');
    } on http.ClientException {
      throw const AssistantException(
        'Tidak bisa terhubung ke Gemini. Periksa koneksi internet.',
      );
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

    String _httpError(int code, dynamic json, String modelName) {
    String message = '';
    String status = '';
    if (json is Map && json['error'] is Map) {
      message = (json['error']['message'] ?? '').toString();
      status = (json['error']['status'] ?? '').toString();
    }
    if (message.length > 220) message = '${message.substring(0, 220)}…';
    final String detail =
        message.isEmpty ? '' : ' Pesan dari Google: "$message" ($status).';
    final String lower = message.toLowerCase();

    if (code == 400 && (lower.contains('api key') || lower.contains('api_key'))) {
      return 'Kunci API tidak valid (kode 400).$detail Pastikan kunci disalin utuh, tanpa spasi.';
    }
    if (code == 401 || code == 403) {
      return 'Kunci ditolak (kode $code).$detail Pastikan kunci dibuat lewat "Create API key" di aistudio.google.com/apikey, disalin utuh, dan akun Google-mu boleh memakai Gemini API.';
    }
    if (code == 404) {
      return 'Model "$modelName" tidak ditemukan. Ganti nama model di pengaturan AI (coba gemini-3.6-flash).';
    }
    if (code == 429) {
      return 'Batas pemakaian gratis Gemini sedang tercapai. Tunggu sebentar lalu coba lagi.';
    }
    if (code >= 500) {
      return 'Server Gemini sedang sibuk. Coba lagi sebentar.';
    }
    return 'Gemini membalas dengan kode $code.$detail';
  }
}