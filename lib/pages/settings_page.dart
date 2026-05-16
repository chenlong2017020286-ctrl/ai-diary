import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/ai_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  String _model = 'deepseek-chat';
  bool _enableMoodAnalysis = true;
  bool _enableAutoTags = true;
  bool _enableSummary = true;
  bool _enableWritingPrompt = true;
  bool _showKey = false;
  bool _isTesting = false;

  final _models = ['deepseek-chat', 'deepseek-reasoner'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<AIConfigStore>().config;
      _apiKeyController.text = config.apiKey;
      _baseUrlController.text = config.baseUrl;
      _model = config.model;
      _enableMoodAnalysis = config.enableMoodAnalysis;
      _enableAutoTags = config.enableAutoTags;
      _enableSummary = config.enableSummary;
      _enableWritingPrompt = config.enableWritingPrompt;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final config = AIConfig(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _model,
      enableMoodAnalysis: _enableMoodAnalysis,
      enableAutoTags: _enableAutoTags,
      enableSummary: _enableSummary,
      enableWritingPrompt: _enableWritingPrompt,
    );

    await context.read<AIConfigStore>().saveConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入 API Key')),
      );
      return;
    }

    setState(() => _isTesting = true);

    final tempConfig = AIConfig(
      apiKey: apiKey,
      baseUrl: _baseUrlController.text.trim(),
      model: _model,
    );
    final service = AIService(tempConfig);

    try {
      await service.chatAboutDiary([], '回复"ok"');
      service.dispose();
      if (mounted) {
        setState(() => _isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接成功！API Key 有效'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      service.dispose();
      if (mounted) {
        setState(() => _isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Config
          _buildSectionHeader('DeepSeek API 配置', Icons.api, colorScheme),
          const SizedBox(height: 12),

          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            obscureText: !_showKey,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.deepseek.com/v1',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _model,
            decoration: const InputDecoration(
              labelText: '模型',
              prefixIcon: Icon(Icons.model_training),
            ),
            items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _model = v);
            },
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: const Text('测试连接'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('保存设置'),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // AI Features toggle
          _buildSectionHeader('AI 功能开关', Icons.tune, colorScheme),
          const SizedBox(height: 12),

          _buildSwitchTile(
            '心情分析',
            '分析日记内容的情感倾向',
            Icons.mood,
            _enableMoodAnalysis,
            (v) => setState(() => _enableMoodAnalysis = v),
            colorScheme,
          ),
          _buildSwitchTile(
            '智能标签',
            '自动提取关键词标签',
            Icons.label_outline,
            _enableAutoTags,
            (v) => setState(() => _enableAutoTags = v),
            colorScheme,
          ),
          _buildSwitchTile(
            '日记总结',
            '生成周报/月报摘要',
            Icons.summarize_outlined,
            _enableSummary,
            (v) => setState(() => _enableSummary = v),
            colorScheme,
          ),
          _buildSwitchTile(
            '写作灵感',
            'AI 生成日记写作引导',
            Icons.lightbulb_outline,
            _enableWritingPrompt,
            (v) => setState(() => _enableWritingPrompt = v),
            colorScheme,
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('关于', Icons.info_outline, colorScheme),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 智能日记 v1.0.0',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    '基于 Flutter 开发，支持 DeepSeek API 云端 AI 分析。\n'
                    '数据完全存储在本地，AI 分析仅将日记内容发送到您配置的 API。\n'
                    '如何获取 DeepSeek API Key：\n'
                    '1. 访问 platform.deepseek.com\n'
                    '2. 注册并创建 API Key\n'
                    '3. 将 Key 填入上方配置栏',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Row(children: [
      Icon(icon, size: 20, color: colorScheme.primary),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.primary)),
    ]);
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
