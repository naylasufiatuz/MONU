import 'package:monu/services/assistant_context.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.note,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final ChatRole role;
  final String text;

  /// Catatan kecil di bawah jawaban (contoh: dijawab Mode Contoh karena Gemini gagal).
  final String? note;
  final DateTime time;
}

class AssistantException implements Exception {
  const AssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mesin penjawab. Ada dua: Gemini (AI) dan LocalEngine (aturan otomatis).
abstract class AssistantEngine {
  String get label;

  /// [history] selalu berakhir dengan pertanyaan terbaru dari pengguna.
  Future<String> reply({
    required List<ChatMessage> history,
    required AssistantData data,
  });
}