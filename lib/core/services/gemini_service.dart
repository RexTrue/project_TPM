import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/api_constants.dart';

/// Service untuk komunikasi dengan Google Gemini API
class GeminiService {
  late GenerativeModel _model;
  late ChatSession _chatSession;
  bool _isInitialized = false;
  String? _apiKey;
  String _activeModel = ApiConstants.geminiModel;

  static const List<String> _fallbackModels = [
    ApiConstants.geminiModel,
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
  ];

  /// Initialize Gemini service
  void initialize({String? apiKey}) {
    if (!_isInitialized) {
      final key = apiKey ?? ApiConstants.geminiApiKey;
      if (key.trim().isEmpty || key.contains('YOUR_')) {
        _isInitialized = false;
        return;
      }

      _apiKey = key;
      _activeModel = ApiConstants.geminiModel;
      _model = GenerativeModel(model: _activeModel, apiKey: key);

      // Initialize chat session untuk multi-turn conversation
      _chatSession = _model.startChat();
      _isInitialized = true;
    }
  }

  Future<GenerateContentResponse> _sendWithFallback(String message) async {
    Exception? lastError;
    final key = _apiKey ?? ApiConstants.geminiApiKey;
    final tried = <String>{};

    for (final modelName in _fallbackModels) {
      if (modelName.trim().isEmpty || !tried.add(modelName)) continue;
      try {
        if (modelName != _activeModel) {
          _activeModel = modelName;
          _model = GenerativeModel(model: _activeModel, apiKey: key);
          _chatSession = _model.startChat();
        }
        return await _chatSession.sendMessage(Content.text(message));
      } on Exception catch (e) {
        lastError = e;
        final lower = e.toString().toLowerCase();
        final canRetryModel =
            lower.contains('not found') ||
            lower.contains('not supported') ||
            lower.contains('model');
        if (!canRetryModel) rethrow;
      }
    }

    throw lastError ?? Exception('Tidak ada model Gemini yang bisa dipakai.');
  }

  /// Send message to Gemini and get response
  Future<String> sendMessage(String message) async {
    try {
      if (!_isInitialized) {
        initialize();
        if (!_isInitialized) {
          return 'Gemini API belum dikonfigurasi. Jalankan aplikasi dengan --dart-define=GEMINI_API_KEY=YOUR_KEY atau isi key Gemini di konfigurasi environment.';
        }
      }

      // System prompt untuk membuat AI lebih fokus sebagai tutor
      final response = await _sendWithFallback(message);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }

      return 'Maaf, saya tidak bisa memproses pesan Anda. Silakan coba lagi.';
    } catch (e) {
      _isInitialized = false;
      return 'Gemini gagal merespons. Pastikan koneksi internet aktif dan API key masih memiliki kuota. Detail: $e';
    }
  }

  /// Send message with system context (untuk digunakan di masa depan)
  Future<String> sendMessageWithContext(
    String message, {
    String systemContext = '',
  }) async {
    try {
      if (!_isInitialized) {
        initialize();
        if (!_isInitialized) {
          return 'Gemini API belum dikonfigurasi. Jalankan aplikasi dengan --dart-define=GEMINI_API_KEY=YOUR_KEY atau isi key Gemini di konfigurasi environment.';
        }
      }

      // Combine system context dengan user message
      final fullMessage = systemContext.isNotEmpty
          ? '$systemContext\n\nPertanyaan: $message'
          : message;

      final response = await _sendWithFallback(fullMessage);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }

      return 'Maaf, saya tidak bisa memproses pesan Anda.';
    } catch (e) {
      _isInitialized = false;
      return 'Gemini gagal merespons. Pastikan koneksi internet aktif dan API key masih memiliki kuota. Detail: $e';
    }
  }

  /// Clear chat history
  void clearHistory() {
    if (!_isInitialized) return;
    _chatSession = _model.startChat();
  }

  /// Get chat history (untuk logging atau debugging)
  List<Content> getChatHistory() {
    return _chatSession.history.toList();
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}
