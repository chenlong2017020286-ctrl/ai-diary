import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_config.dart';

class SettingsService {
  static const _keyApiKey = 'ai_api_key';
  static const _keyBaseUrl = 'ai_base_url';
  static const _keyModel = 'ai_model';
  static const _keyMoodAnalysis = 'ai_mood_analysis';
  static const _keyAutoTags = 'ai_auto_tags';
  static const _keySummary = 'ai_summary';
  static const _keyWritingPrompt = 'ai_writing_prompt';

  Future<AIConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return AIConfig(
      apiKey: prefs.getString(_keyApiKey) ?? '',
      baseUrl: prefs.getString(_keyBaseUrl) ?? 'https://api.deepseek.com/v1',
      model: prefs.getString(_keyModel) ?? 'deepseek-chat',
      enableMoodAnalysis: prefs.getBool(_keyMoodAnalysis) ?? true,
      enableAutoTags: prefs.getBool(_keyAutoTags) ?? true,
      enableSummary: prefs.getBool(_keySummary) ?? true,
      enableWritingPrompt: prefs.getBool(_keyWritingPrompt) ?? true,
    );
  }

  Future<void> saveConfig(AIConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, config.apiKey);
    await prefs.setString(_keyBaseUrl, config.baseUrl);
    await prefs.setString(_keyModel, config.model);
    await prefs.setBool(_keyMoodAnalysis, config.enableMoodAnalysis);
    await prefs.setBool(_keyAutoTags, config.enableAutoTags);
    await prefs.setBool(_keySummary, config.enableSummary);
    await prefs.setBool(_keyWritingPrompt, config.enableWritingPrompt);
  }
}
