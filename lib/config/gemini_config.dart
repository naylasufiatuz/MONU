/// ============================================================
///  KONFIGURASI AI ASSISTANT (GOOGLE GEMINI)
/// ============================================================
class GeminiConfig {
  GeminiConfig._();

  /// Kunci API default Google Gemini (diisi lewat Settings aplikasi atau --dart-define)
  static const String defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Model Gemini yang digunakan
  static const String defaultModel = 'gemini-1.5-flash';
}
