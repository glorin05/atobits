class AppConfig {
  // Load from environment — never hardcode
  static const String groqApiKey = 
    String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    
  static const String groqModel = 'llama-3.1-8b-instant';
  static const String coachProxyUrl = 
    'YOUR_CLOUDFLARE_WORKER_URL_HERE';
    
  static bool get isConfigured => groqApiKey.isNotEmpty || 
    coachProxyUrl.isNotEmpty;
}
