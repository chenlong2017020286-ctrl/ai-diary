import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/diary_entry.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DiaryEntry? _entry;
  bool _loading = true;
  bool _isAnalyzing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && _entry?.id != id) {
      _loadEntry(id);
    }
  }

  void _loadEntry(String id) {
    final entry = context.read<DiaryStore>().getEntry(id);
    setState(() {
      _entry = entry;
      _loading = false;
    });
  }

  Future<void> _runAIAnalysis() async {
    if (_entry == null) return;
    final aiService = context.read<AIConfigStore>().aiService;
    if (aiService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 API Key')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final moodResult = await aiService.analyzeMood(_entry!.content);
      final tags = await aiService.generateTags(_entry!.content);

      final updated = _entry!.copyWith(
        mood: moodResult['mood'] ?? _entry!.mood,
        moodScore: moodResult['score'] ?? _entry!.moodScore,
        aiTags: tags,
        aiAnalysis: moodResult['analysis'],
      );

      await context.read<DiaryStore>().updateEntry(updated);
      setState(() {
        _entry = updated;
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 分析完成')),
      );
    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('日记')),
        body: const Center(child: Text('日记不存在')),
      );
    }

    final entry = _entry!;
    final allTags = [...entry.tags, ...entry.aiTags];
    final hasAiAnalysis =
        entry.aiAnalysis != null && entry.aiAnalysis!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            entry.createdAt.toString().substring(0, 10)),
        actions: [
          IconButton(
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.psychology_outlined),
            tooltip: 'AI 分析',
            onPressed: _isAnalyzing ? null : _runAIAnalysis,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.pushNamed(context, '/editor', arguments: entry.id);
              if (mounted) _loadEntry(entry.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认删除'),
                  content: Text('确定要删除「${entry.title}」吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('删除',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await context.read<DiaryStore>().deleteEntry(entry.id);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.mood, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        entry.updatedAt != entry.createdAt
                            ? '更新于 ${entry.updatedAt.toString().substring(0, 16)}'
                            : '创建于 ${entry.createdAt.toString().substring(0, 16)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (allTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allTags.map((tag) {
                  final isAiTag = entry.aiTags.contains(tag) && !entry.tags.contains(tag);
                  return Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAiTag) ...[
                          Icon(Icons.auto_awesome, size: 14,
                              color: colorScheme.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(tag, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isAiTag
                        ? colorScheme.primaryContainer.withOpacity(0.5)
                        : colorScheme.surfaceContainerHighest,
                  );
                }).toList(),
              ),
            ],

            if (hasAiAnalysis) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.psychology, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('AI 分析',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          )),
                    ]),
                    const SizedBox(height: 8),
                    Text(entry.aiAnalysis!,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        )),
                  ],
                ),
              ),
            ],

            const Divider(height: 32),

            SelectableText(
              entry.content,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }
}
