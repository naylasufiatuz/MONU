import 'package:flutter/foundation.dart';
import 'package:monu/config/gemini_config.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/services/assistant_context.dart';
import 'package:monu/services/assistant_models.dart';
import 'package:monu/services/gemini_engine.dart';
import 'package:monu/services/local_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mengelola percakapan, pilihan mesin (Gemini atau Mode Contoh), dan kunci API.
class AssistantProvider extends ChangeNotifier {
  AssistantProvider({
    required this._monitor,
    required this._settings,
  });

  static const String _kKey = 'ai_api_key';
  static const String _kModel = 'ai_model';

  final MonitorProvider _monitor;
  final SettingsProvider _settings;

  SharedPreferences? _prefs;
  String _apiKey = GeminiConfig.defaultApiKey;
  String _model = GeminiConfig.defaultModel;
  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _busy = false;
  bool _disposed = false;

  bool get hasKey => _apiKey.isNotEmpty;
  String get model => _model;
  bool get busy => _busy;
  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);
  String get engineLabel => hasKey ? 'Gemini' : 'Mode Contoh';

  String get maskedKey {
    if (_apiKey.length < 4) return '';
    return '••••${_apiKey.substring(_apiKey.length - 4)}';
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final String savedKey = prefs.getString(_kKey) ?? '';
    _apiKey = savedKey.isNotEmpty ? savedKey : GeminiConfig.defaultApiKey;
    _model = prefs.getString(_kModel) ?? GeminiConfig.defaultModel;
    _notify();
  }

  /// [apiKey] kosong = pertahankan kunci yang sudah ada.
  Future<void> saveSettings({
    required String apiKey,
    required String model,
  }) async {
    final String key = apiKey.trim();
    if (key.isNotEmpty) _apiKey = key;
    final String m = model.trim();
    _model = m.isEmpty ? GeminiEngine.defaultModel : m;
    _notify();
    await _prefs?.setString(_kKey, _apiKey);
    await _prefs?.setString(_kModel, _model);
  }

  Future<void> clearKey() async {
    _apiKey = '';
    _notify();
    await _prefs?.remove(_kKey);
  }

  /// Mengembalikan pesan error, atau null jika berhasil.
  Future<String?> testGemini({String? apiKey, String? model}) async {
    final String key = (apiKey == null || apiKey.isEmpty) ? _apiKey : apiKey;
    final String m = (model == null || model.isEmpty) ? _model : model;
    if (key.isEmpty) return 'Isi kunci API terlebih dahulu.';
    try {
      await GeminiEngine.test(apiKey: key, model: m);
      return null;
    } on AssistantException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  void clearChat() {
    _messages.clear();
    _notify();
  }

  Future<void> send(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty || _busy) return;

    _messages.add(ChatMessage(role: ChatRole.user, text: text));
    _busy = true;
    _notify();

    try {
      final AssistantData data =
          await AssistantDataBuilder.build(_monitor, _settings);
      final List<ChatMessage> history = _historyForModel();

      String answer;
      String? note;
      if (hasKey) {
        try {
          answer = await GeminiEngine(apiKey: _apiKey, model: _model)
              .reply(history: history, data: data);
        } catch (error) {
          note =
              'Dijawab oleh Mode Contoh karena Gemini gagal: ${_describe(error)}';
          answer = await LocalEngine().reply(history: history, data: data);
        }
      } else {
        answer = await LocalEngine().reply(history: history, data: data);
      }

      if (_disposed) return;
      _messages.add(
        ChatMessage(role: ChatRole.assistant, text: answer, note: note),
      );
    } catch (error) {
      if (_disposed) return;
      _messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Maaf, ada masalah saat menyiapkan jawaban: ${_describe(error)}',
        ),
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  List<ChatMessage> _historyForModel() {
    return _messages.length > 12
        ? _messages.sublist(_messages.length - 12)
        : List<ChatMessage>.of(_messages);
  }

  String _describe(Object error) =>
      error is AssistantException ? error.message : 'Terjadi kesalahan: $error';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}