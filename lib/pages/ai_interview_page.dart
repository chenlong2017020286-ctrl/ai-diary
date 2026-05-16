import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../models/diary_entry.dart';

class AIInterviewPage extends StatefulWidget {
  const AIInterviewPage({super.key});

  @override
  State<AIInterviewPage> createState() => _AIInterviewPageState();
}

enum InterviewStage { chatting, reviewing, saving }

class _AIInterviewPageState extends State<AIInterviewPage> {
  final _answerController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  final List<Map<String, String>> _conversation = [];
  InterviewStage _stage = InterviewStage.chatting;
  bool _aiThinking = false;
  bool _isSaving = false;
  String _generatedTitle = '';
  String _generatedContent = '';
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInterview();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先配置 API Key')),
        );
      }
      return;
    }

    setState(() => _aiThinking = true);

    final entries = context.read<DiaryStore>().entries;
    final last = entries.isNotEmpty ? entries.first : null;
    final question = await aiService.startInterview(last, DateTime.now());

    if (mounted) {
      setState(() {
        _conversation.add({'role': 'assistant', 'content': question});
        _aiThinking = false;
      });
    }
  }

  Future<void> _sendAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) return;

    // Check if user wants to end
    if (text.contains('写日记') || text.contains('结束') || text.contains('生成')) {
      await _finishInterview();
      return;
    }

    setState(() {
      _conversation.add({'role': 'user', 'content': text});
      _aiThinking = true;
    });
    _answerController.clear();

    final question = await aiService.nextQuestion(_conversation);

    if (mounted) {
      setState(() {
        _conversation.add({'role': 'assistant', 'content': question});
        _aiThinking = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _finishInterview() async {
    if (_conversation.isEmpty) return;

    // Add user's last message if any
    final text = _answerController.text.trim();
    if (text.isNotEmpty && !text.contains('写日记') && !text.contains('结束')) {
      _conversation.add({'role': 'user', 'content': text});
    }
    _answerController.clear();

    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) return;

    setState(() {
      _aiThinking = true;
      _stage = InterviewStage.reviewing;
    });

    // Filter out AI messages for generating summary
    final result = await aiService.generateDiaryFromInterview(_conversation);

    if (mounted) {
      _generatedTitle = result['title'] ?? '今日日记';
      _generatedContent = result['content'] ?? '';
      _titleController.text = _generatedTitle;
      _contentController.text = _generatedContent;
      setState(() => _aiThinking = false);
    }
  }

  Future<void> _saveDiary() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能为空')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final entry = DiaryEntry(
      id: _uuid.v4(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      mood: '🙂',
      tags: ['AI对话'],
      createdAt: now,
      updatedAt: now,
    );

    // Run AI analysis for mood and tags
    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService != null) {
      try {
        final moodResult = await aiService.analyzeMood(entry.content);
        final tags = await aiService.generateTags(entry.content);
        final updated = entry.copyWith(
          mood: moodResult['mood'],
          moodScore: moodResult['score'],
          aiTags: tags,
          aiAnalysis: moodResult['analysis'],
        );
        await context.read<DiaryStore>().addEntry(updated);
      } catch (_) {
        await context.read<DiaryStore>().addEntry(entry);
      }
    } else {
      await context.read<DiaryStore>().addEntry(entry);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日记已保存')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 对话写日记'),
        actions: [
          if (_stage == InterviewStage.chatting && _conversation.isNotEmpty)
            TextButton(
              onPressed: _aiThinking ? null : _finishInterview,
              child: const Text('生成日记'),
            ),
        ],
      ),
      body: _stage == InterviewStage.reviewing
          ? _buildReviewStage(colorScheme)
          : _buildChatStage(colorScheme),
    );
  }

  Widget _buildChatStage(ColorScheme colorScheme) {
    return Column(
      children: [
        Expanded(
          child: _conversation.isEmpty && _aiThinking
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversation.length + (_aiThinking ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (_aiThinking && i == _conversation.length) {
                      return _buildTypingIndicator(colorScheme);
                    }
                    final msg = _conversation[i];
                    final isUser = msg['role'] == 'user';
                    return _buildMessage(msg['content'] ?? '', isUser, colorScheme);
                  },
                ),
        ),
        if (_stage == InterviewStage.chatting)
          _buildInputBar(colorScheme),
      ],
    );
  }

  Widget _buildMessage(String text, bool isUser, ColorScheme colorScheme) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('AI 提问',
                        style: TextStyle(
                            fontSize: 11, color: colorScheme.primary)),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(colorScheme, 0),
            const SizedBox(width: 4),
            _buildDot(colorScheme, 300),
            const SizedBox(width: 4),
            _buildDot(colorScheme, 600),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(ColorScheme colorScheme, int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (ctx, value, _) => Opacity(
        opacity: value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                hintText: '输入你的回答...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendAnswer(),
              enabled: !_aiThinking,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _aiThinking ? null : _sendAnswer,
            icon: const Icon(Icons.send, size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _buildReviewStage(ColorScheme colorScheme) {
    if (_aiThinking) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI 正在生成日记...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conversation recap
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.chat_bubble_outline, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('对话回顾',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: colorScheme.primary)),
                ]),
                const SizedBox(height: 10),
                ..._conversation.where((m) => m['role'] == 'user').map((m) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('💬 ${m['content']}',
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withOpacity(0.7))),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('编辑日记', style: TextStyle(fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 8),

          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: '标题'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _contentController,
            decoration: const InputDecoration(hintText: '日记内容', alignLabelWithHint: true),
            maxLines: 10,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveDiary,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('保存日记'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
