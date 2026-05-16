import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _chatHistory = [];
  String _summary = '';
  String _yearReport = '';
  String _writingPrompts = '';
  bool _loadingSummary = false;
  bool _loadingReport = false;
  bool _loadingPrompts = false;
  bool _loadingChat = false;

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasApiKey =>
      context.read<AIConfigStore>().config.isConfigured;

  Future<void> _generateSummary() async {
    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) {
      _showNoConfig();
      return;
    }

    setState(() => _loadingSummary = true);
    final entries = context.read<DiaryStore>().entries;
    final recent = entries.take(30).toList();
    final text = await aiService.generateSummary(recent);
    if (mounted) {
      setState(() {
        _summary = text;
        _loadingSummary = false;
      });
    }
  }

  Future<void> _generateYearReport() async {
    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) {
      _showNoConfig();
      return;
    }

    setState(() => _loadingReport = true);
    final entries = context.read<DiaryStore>().entries;
    final text = await aiService.generateYearReport(entries);
    if (mounted) {
      setState(() {
        _yearReport = text;
        _loadingReport = false;
      });
    }
  }

  Future<void> _generateWritingPrompts() async {
    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) {
      _showNoConfig();
      return;
    }

    setState(() => _loadingPrompts = true);
    final entries = context.read<DiaryStore>().entries;
    final last = entries.isNotEmpty ? entries.first : null;
    final text = await aiService.generateWritingPrompt(last);
    if (mounted) {
      setState(() {
        _writingPrompts = text;
        _loadingPrompts = false;
      });
    }
  }

  Future<void> _sendChat() async {
    final question = _chatController.text.trim();
    if (question.isEmpty) return;

    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) {
      _showNoConfig();
      return;
    }

    setState(() {
      _chatHistory.add({'role': 'user', 'content': question});
      _loadingChat = true;
    });
    _chatController.clear();

    final entries = context.read<DiaryStore>().entries;
    final answer = await aiService.chatAboutDiary(entries.take(50).toList(), question);

    if (mounted) {
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': answer});
        _loadingChat = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showNoConfig() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在设置中配置 DeepSeek API Key')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final configStore = context.watch<AIConfigStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('AI 功能中心')),
      body: configStore.config.isConfigured
          ? _buildContent(colorScheme)
          : _buildNoConfig(colorScheme),
    );
  }

  Widget _buildNoConfig(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, size: 64,
                color: colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('AI 功能需要配置 API Key',
                style: TextStyle(
                    fontSize: 18, color: colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('去配置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Interview - Featured entry
          Card(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/ai-interview'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.chat, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI 对话写日记',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('AI 像朋友一样提问，帮你完成一篇日记',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16,
                      color: colorScheme.onSurface.withOpacity(0.3)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Writing prompts
          _buildSection(
            title: '写作灵感',
            icon: Icons.lightbulb_outline,
            onTap: _generateWritingPrompts,
            loading: _loadingPrompts,
            colorScheme: colorScheme,
          ),
          if (_writingPrompts.isNotEmpty)
            _buildResultCard(_writingPrompts, colorScheme),

          const SizedBox(height: 12),

          // Summary
          _buildSection(
            title: '日记总结',
            icon: Icons.summarize_outlined,
            onTap: _generateSummary,
            loading: _loadingSummary,
            colorScheme: colorScheme,
          ),
          if (_summary.isNotEmpty) _buildResultCard(_summary, colorScheme),

          const SizedBox(height: 12),

          // Year report
          _buildSection(
            title: '年度报告',
            icon: Icons.auto_awesome,
            onTap: _generateYearReport,
            loading: _loadingReport,
            colorScheme: colorScheme,
          ),
          if (_yearReport.isNotEmpty) _buildResultCard(_yearReport, colorScheme),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          Text('AI 对话',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface)),
          Text('向 AI 提问关于你日记的事情',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 12),

          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _chatHistory.isEmpty
                      ? Center(
                          child: Text('试着问："我这周最开心的是哪天？"',
                              style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.3))))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _chatHistory.length + (_loadingChat ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (_loadingChat && i == _chatHistory.length) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            final msg = _chatHistory[i];
                            final isUser = msg['role'] == 'user';
                            return Align(
                              alignment:
                                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                                child: Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    color: isUser
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: const InputDecoration(
                          hintText: '问点什么...',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendChat(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _loadingChat ? null : _sendChat,
                      icon: const Icon(Icons.send, size: 18),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool loading,
    required ColorScheme colorScheme,
  }) {
    return Card(
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.play_arrow, color: colorScheme.primary),
          ]),
        ),
      ),
    );
  }

  Widget _buildResultCard(String text, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: colorScheme.onSurface)),
      ),
    );
  }
}
