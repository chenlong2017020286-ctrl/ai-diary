class AIConfig {
  String apiKey;
  String baseUrl;
  String model;
  bool enableMoodAnalysis;
  bool enableAutoTags;
  bool enableSummary;
  bool enableWritingPrompt;

  AIConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.model = 'deepseek-chat',
    this.enableMoodAnalysis = true,
    this.enableAutoTags = true,
    this.enableSummary = true,
    this.enableWritingPrompt = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'enableMoodAnalysis': enableMoodAnalysis,
      'enableAutoTags': enableAutoTags,
      'enableSummary': enableSummary,
      'enableWritingPrompt': enableWritingPrompt,
    };
  }

  factory AIConfig.fromMap(Map<String, dynamic> map) {
    return AIConfig(
      apiKey: map['apiKey'] as String? ?? '',
      baseUrl: map['baseUrl'] as String? ?? 'https://api.deepseek.com/v1',
      model: map['model'] as String? ?? 'deepseek-chat',
      enableMoodAnalysis: map['enableMoodAnalysis'] as bool? ?? true,
      enableAutoTags: map['enableAutoTags'] as bool? ?? true,
      enableSummary: map['enableSummary'] as bool? ?? true,
      enableWritingPrompt: map['enableWritingPrompt'] as bool? ?? true,
    );
  }

  bool get isConfigured => apiKey.isNotEmpty;
}
