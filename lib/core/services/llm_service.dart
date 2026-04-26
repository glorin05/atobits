import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class LlmService {
  static const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  static String get _coachApiUrl => AppConfig.coachProxyUrl;
  static const String _coachApiToken = String.fromEnvironment(
    'COACH_API_TOKEN',
    defaultValue: '',
  );
  static String get _groqApiKey => AppConfig.groqApiKey;
  static String get _groqModel => AppConfig.groqModel;

  bool get _hasProxy =>
      _coachApiUrl.trim().isNotEmpty && _coachApiToken.trim().isNotEmpty;
  bool get _hasGroq => _groqApiKey.trim().isNotEmpty;

  bool get isConfigured => AppConfig.isConfigured || _hasProxy;

  String get providerName {
    if (_hasProxy) return 'Proxy';
    if (_hasGroq) return 'Groq';
    return 'none';
  }

  Future<String> generateCoachReply({
    required String systemPrompt,
    required List<Map<String, String>> conversation,
  }) async {
    if (_hasProxy) {
      return _generateViaProxy(
        systemPrompt: systemPrompt,
        conversation: conversation,
      );
    }

    if (!isConfigured) {
      throw StateError(
        'No LLM configured. Use --dart-define=COACH_API_URL=https://your-api '
        '--dart-define=COACH_API_TOKEN=your_token '
        'or --dart-define=GROQ_API_KEY=your_key',
      );
    }

    final apiKey = _groqApiKey.trim();
    final model = _groqModel.trim();

    if (apiKey.isEmpty || apiKey.toUpperCase() == 'YOUR_KEY') {
      throw StateError(
        'API key is empty or placeholder. Please provide your real API key.',
      );
    }

    if (!apiKey.startsWith('gsk_') && !apiKey.startsWith('sk-')) {
      throw StateError(
        'API key format looks invalid. Groq keys usually start with gsk_.',
      );
    }
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...conversation,
    ];

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.7,
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'LLM request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('LLM returned no choices.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw StateError('LLM returned empty content.');
    }

    return content;
  }

  Future<String> _generateViaProxy({
    required String systemPrompt,
    required List<Map<String, String>> conversation,
  }) async {
    final proxyUri = Uri.tryParse(_coachApiUrl.trim());
    if (proxyUri == null) {
      throw StateError('COACH_API_URL is invalid or missing.');
    }

    final response = await http
        .post(
          proxyUri,
          headers: {
            'Content-Type': 'application/json',
            if (_coachApiToken.trim().isNotEmpty)
              'Authorization': 'Bearer ${_coachApiToken.trim()}',
          },
          body: jsonEncode({
            'systemPrompt': systemPrompt,
            'conversation': conversation,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Proxy request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['reply']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw StateError('Proxy returned empty reply.');
    }

    return content;
  }
}
