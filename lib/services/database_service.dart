import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/diary_entry.dart';

class DatabaseService {
  static Database? _database;
  static const _dbName = 'ai_diary.db';
  static const _tableName = 'diary_entries';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        mood TEXT DEFAULT '🙂',
        moodScore REAL DEFAULT 0.0,
        tags TEXT DEFAULT '',
        aiTags TEXT DEFAULT '',
        aiSummary TEXT DEFAULT '',
        aiAnalysis TEXT DEFAULT '',
        imagePaths TEXT DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_created_at ON $_tableName(createdAt DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_mood ON $_tableName(moodScore)',
    );
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => DiaryEntry.fromMap(map)).toList();
  }

  Future<List<DiaryEntry>> searchEntries(String query) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ? OR aiTags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => DiaryEntry.fromMap(map)).toList();
  }

  Future<List<DiaryEntry>> getEntriesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'createdAt BETWEEN ? AND ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => DiaryEntry.fromMap(map)).toList();
  }

  Future<List<DiaryEntry>> getEntriesByTag(String tag) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'tags LIKE ? OR aiTags LIKE ?',
      whereArgs: ['%$tag%', '%$tag%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => DiaryEntry.fromMap(map)).toList();
  }

  Future<DiaryEntry?> getEntry(String id) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return DiaryEntry.fromMap(maps.first);
  }

  Future<void> insertEntry(DiaryEntry entry) async {
    final db = await database;
    await db.insert(_tableName, entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    final db = await database;
    await db.update(
      _tableName,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getTagFrequency() async {
    final entries = await getAllEntries();
    final Map<String, int> freq = {};
    for (final entry in entries) {
      for (final tag in [...entry.tags, ...entry.aiTags]) {
        freq[tag] = (freq[tag] ?? 0) + 1;
      }
    }
    return freq;
  }

  Future<Map<DateTime, double>> getMoodTimeline(
    DateTime start,
    DateTime end,
  ) async {
    final entries = await getEntriesByDateRange(start, end);
    return {
      for (final entry in entries)
        DateTime(
          entry.createdAt.year,
          entry.createdAt.month,
          entry.createdAt.day,
        ): entry.moodScore,
    };
  }
}
