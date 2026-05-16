class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final String mood;
  final double moodScore;
  final List<String> tags;
  final List<String> aiTags;
  final String? aiSummary;
  final String? aiAnalysis;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    this.mood = '🙂',
    this.moodScore = 0.0,
    this.tags = const [],
    this.aiTags = const [],
    this.aiSummary,
    this.aiAnalysis,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'moodScore': moodScore,
      'tags': tags.join(','),
      'aiTags': aiTags.join(','),
      'aiSummary': aiSummary ?? '',
      'aiAnalysis': aiAnalysis ?? '',
      'imagePaths': imagePaths.join(','),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      mood: map['mood'] as String? ?? '🙂',
      moodScore: (map['moodScore'] as num?)?.toDouble() ?? 0.0,
      tags: _parseTags(map['tags']),
      aiTags: _parseTags(map['aiTags']),
      aiSummary: _parseNullable(map['aiSummary']),
      aiAnalysis: _parseNullable(map['aiAnalysis']),
      imagePaths: _parseTags(map['imagePaths']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static List<String> _parseTags(dynamic value) {
    if (value == null || value.toString().isEmpty) return [];
    return value.toString().split(',').where((s) => s.isNotEmpty).toList();
  }

  static String? _parseNullable(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return value.toString();
  }

  DiaryEntry copyWith({
    String? id,
    String? title,
    String? content,
    String? mood,
    double? moodScore,
    List<String>? tags,
    List<String>? aiTags,
    String? aiSummary,
    String? aiAnalysis,
    List<String>? imagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      moodScore: moodScore ?? this.moodScore,
      tags: tags ?? this.tags,
      aiTags: aiTags ?? this.aiTags,
      aiSummary: aiSummary ?? this.aiSummary,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
