/// API Constants
class ApiConstants {
  // Google Gemini API
  // Dapatkan API key dari: https://aistudio.google.com/apikey
  // Jalankan dengan:
  // flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static String get geminiApiKey {
    const raw = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    return raw.trim();
  }

  // Model yang digunakan. Bisa dioverride:
  // flutter run --dart-define=GEMINI_MODEL=gemini-2.5-flash
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  // Timeout settings
  static const int connectTimeout = 30; // detik
  static const int receiveTimeout = 30; // detik
}
