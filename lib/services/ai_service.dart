import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/diary_entry.dart';
import '../models/ai_config.dart';

class AIService {
  final AIConfig _config;
  final http.Client _client = http.Client();

  AIService(this._config);

  Future<Map<String, String>> _headers() async {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_config.apiKey}',
    };
  }

  Future<String> _chat(List<Map<String, String>> messages) async {
    final uri = Uri.parse('${_config.baseUrl}/chat/completions');
    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'model': _config.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2000,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> analyzeMood(String content) async {
    if (!_config.isConfigured || !_config.enableMoodAnalysis) {
      return {'mood': '🙂', 'score': 0.0, 'analysis': ''};
    }

    final prompt = '''分析以下日记的情感，返回JSON格式：
{
  "mood": "从以下选择一个：😊开心 😢伤心 😠生气 😰焦虑 😌平静 🥰感动 🤔思考 💪激励 😴疲惫 😎酷",
  "score": "情感强度从 -1.0 到 1.0",
  "analysis": "简短的情感分析（50字以内）"
}

日记内容：$content''';

    try {
      final result = await _chat([
        {'role': 'system', 'content': '你是一个情感分析助手，严格按照JSON格式返回。'},
        {'role': 'user', 'content': prompt},
      ]);
      final start = result.indexOf('{');
      final end = result.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final json = jsonDecode(result.substring(start, end + 1));
        return {
          'mood': json['mood'] ?? '🙂',
          'score': (json['score'] as num?)?.toDouble() ?? 0.0,
          'analysis': json['analysis'] ?? '',
        };
      }
    } catch (_) {}
    return {'mood': '🙂', 'score': 0.0, 'analysis': ''};
  }

  Future<List<String>> generateTags(String content) async {
    if (!_config.isConfigured || !_config.enableAutoTags) return [];

    final prompt = '''从以下日记中提取3-5个关键词标签，只返回标签，用逗号分隔，每个标签2-4个字。
不要包含任何解释。

日记内容：$content''';

    try {
      final result = await _chat([
        {'role': 'system', 'content': '你是一个标签提取助手，只返回逗号分隔的标签。'},
        {'role': 'user', 'content': prompt},
      ]);
      return result
          .split(',')
          .map((t) => t.trim().replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z]'), ''))
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> generateSummary(List<DiaryEntry> entries) async {
    if (!_config.isConfigured || !_config.enableSummary || entries.isEmpty) {
      return '';
    }

    final diaryTexts = entries.map((e) =>
        '【${e.createdAt.toString().substring(0, 16)}】${e.title}\n${e.content}')
        .join('\n\n---\n\n');

    final prompt = '''请总结以下多篇日记内容，生成一个200字以内的周报/月报摘要。
包含：主要事件、情绪变化趋势、值得注意的亮点。

日记内容：
$diaryTexts''';

    try {
      return await _chat([
        {'role': 'system', 'content': '你是一个生活记录总结助手。'},
        {'role': 'user', 'content': prompt},
      ]);
    } catch (_) {
      return '生成摘要失败，请检查API配置。';
    }
  }

  Future<String> generateWritingPrompt(DiaryEntry? lastEntry) async {
    if (!_config.isConfigured || !_config.enableWritingPrompt) return '';

    String context = '';
    if (lastEntry != null) {
      context = '\n最近一篇日记是：${lastEntry.title}\n${lastEntry.content.substring(0, lastEntry.content.length > 100 ? 100 : lastEntry.content.length)}';
    }

    final prompt = '''请生成3个日记写作引导问题，帮助用户开始今天的日记写作。
每个问题一行，用"📝 "开头。
问题应该根据上下文具有启发性。

$context''';

    try {
      return await _chat([
        {'role': 'system', 'content': '你是一个日记写作引导助手，问题简洁有启发性。'},
        {'role': 'user', 'content': prompt},
      ]);
    } catch (_) {
      return '📝 今天发生了什么让你开心的事情？\n📝 你学到了什么新的东西？\n📝 你有什么想对明天的自己说的？';
    }
  }

  Future<String> chatAboutDiary(List<DiaryEntry> entries, String question) async {
    if (!_config.isConfigured) return '请先配置 API Key。';

    final diaryContext = entries.map((e) =>
        '日期：${e.createdAt.toString().substring(0, 10)}\n标题：${e.title}\n内容：${e.content}\n心情：${e.mood}\n标签：${[...e.tags, ...e.aiTags].join(', ')}')
        .join('\n\n---\n\n');

    final prompt = '''以下是用户的日记记录：

$diaryContext

用户的问题是：$question

请基于日记内容回答用户的问题。如果日记中没有相关信息，请诚实地说明。''';

    try {
      return await _chat([
        {'role': 'system', 'content': '你是一个日记助手，基于用户的日记内容回答问题。'},
        {'role': 'user', 'content': prompt},
      ]);
    } catch (_) {
      return 'AI分析失败，请检查API配置。';
    }
  }

  Future<String> generateYearReport(List<DiaryEntry> entries) async {
    if (!_config.isConfigured || entries.isEmpty) return '';

    final totalEntries = entries.length;
    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.content.length);
    final moodScores = entries.where((e) => e.moodScore != 0).toList();
    final avgMood = moodScores.isEmpty ? 0.0 :
        moodScores.map((e) => e.moodScore).reduce((a, b) => a + b) / moodScores.length;
    final allTags = <String, int>{};
    for (final e in entries) {
      for (final t in [...e.tags, ...e.aiTags]) {
        allTags[t] = (allTags[t] ?? 0) + 1;
      }
    }
    final topTags = allTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Tags = topTags.take(5).map((e) => e.key).join(', ');

    final prompt = '''请基于以下日记统计数据，生成一份温暖、个性化的年度回顾报告。
包含：写作概况、情感旅程、关注话题、年度金句、新年寄语。

统计：
- 总篇数：$totalEntries
- 总字数：$totalWords
- 平均心情指数：${avgMood.toStringAsFixed(2)}（-1到1）
- 最常提及话题：$top5Tags

请控制在400字以内，用中文。''';

    try {
      return await _chat([
        {'role': 'system', 'content': '你是一个年度总结生成助手，文风温暖有共鸣。'},
        {'role': 'user', 'content': prompt},
      ]);
    } catch (_) {
      return '年度报告生成失败。';
    }
  }

  void dispose() {
    _client.close();
  }
}
