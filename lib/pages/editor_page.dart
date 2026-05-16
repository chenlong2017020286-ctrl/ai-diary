import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../models/diary_entry.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final _uuid = const Uuid();
  final List<String> _tags = [];
  final List<String> _imagePaths = [];
  String _mood = '🙂';
  bool _showPreview = false;
  bool _isSaving = false;
  bool _isAnalyzing = false;

  DiaryEntry? _editingEntry;
  bool get _isEditing => _editingEntry != null;

  final List<String> _moods = [
    '😊', '😢', '😠', '😰', '😌', '🥰', '🤔', '💪', '😴', '😎',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        final entry = context.read<DiaryStore>().getEntry(args);
        if (entry != null) {
          _editingEntry = entry;
          _titleController.text = entry.title;
          _contentController.text = entry.content;
          _mood = entry.mood;
          _tags.addAll(entry.tags);
          _imagePaths.addAll(entry.imagePaths);
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _analyzeWithAI() async {
    final configStore = context.read<AIConfigStore>();
    final aiService = configStore.aiService;
    if (aiService == null || !configStore.config.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中配置 DeepSeek API Key')),
        );
      }
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final moodResult =
          await aiService.analyzeMood(_contentController.text);
      final aiTags =
          await aiService.generateTags(_contentController.text);

      if (mounted) {
        setState(() {
          _mood = moodResult['mood'] ?? _mood;
          for (final tag in aiTags) {
            if (!_tags.contains(tag)) _tags.add(tag);
          }
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'AI 分析完成: 心情 ${moodResult['mood']}，标签 ${aiTags.join(', ')}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 分析失败: $e')),
        );
      }
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
      id: _editingEntry?.id ?? _uuid.v4(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      mood: _mood,
      tags: List.from(_tags),
      imagePaths: List.from(_imagePaths),
      aiTags: _editingEntry?.aiTags ?? [],
      aiSummary: _editingEntry?.aiSummary,
      aiAnalysis: _editingEntry?.aiAnalysis,
      createdAt: _editingEntry?.createdAt ?? now,
      updatedAt: now,
    );

    final store = context.read<DiaryStore>();
    if (_isEditing) {
      await store.updateEntry(entry);
    } else {
      await store.addEntry(entry);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑日记' : '写日记'),
        actions: [
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.visibility),
            tooltip: _showPreview ? '编辑' : '预览',
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
          if (_contentController.text.length > 50)
            IconButton(
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology),
              tooltip: 'AI 分析',
              onPressed: _isAnalyzing ? null : _analyzeWithAI,
            ),
        ],
      ),
      body: _showPreview ? _buildPreview(colorScheme) : _buildEditor(colorScheme),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDiary,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? '保存' : '发布'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood picker
          Text('选择心情', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (ctx, i) {
                final mood = _moods[i];
                final selected = mood == _mood;
                return GestureDetector(
                  onTap: () => setState(() => _mood = mood),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(mood, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: '标题'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              hintText: '今天发生了什么...',
              alignLabelWithHint: true,
            ),
            maxLines: 12,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 20),

          Text('标签', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 8),

          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) => Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
                backgroundColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
              )).toList(),
            ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    hintText: '添加标签',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addTag,
                icon: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ColorScheme colorScheme) {
    final content = _contentController.text;
    if (content.isEmpty) {
      return Center(
        child: Text(
          '没有内容可以预览',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_titleController.text.isEmpty ? '（无标题）' : _titleController.text,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Text(_mood, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              DateTime.now().toString().substring(0, 10),
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ]),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: _tags.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )).toList()),
          ],
          const Divider(height: 32),
          SelectableText(
            content,
            style: const TextStyle(fontSize: 16, height: 1.8),
          ),
        ],
      ),
    );
  }
}
