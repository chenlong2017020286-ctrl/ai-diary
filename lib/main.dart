import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/ai_service.dart';
import 'services/settings_service.dart';
import 'models/ai_config.dart';
import 'models/diary_entry.dart';
import 'pages/home_page.dart';
import 'pages/editor_page.dart';
import 'pages/detail_page.dart';
import 'pages/ai_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AIDiaryApp());
}

class AIDiaryApp extends StatelessWidget {
  const AIDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => DiaryStore()),
        ChangeNotifierProvider(create: (_) => AIConfigStore()),
      ],
      child: MaterialApp(
        title: 'AI 智能日记',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F9FC),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: const Color(0xFF1E293B),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh')],
        initialRoute: '/',
        routes: {
          '/': (_) => const HomePage(),
          '/editor': (_) => const EditorPage(),
          '/detail': (_) => const DetailPage(),
          '/ai': (_) => const AIPage(),
          '/settings': (_) => const SettingsPage(),
        },
      ),
    );
  }
}

class DiaryStore extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<DiaryEntry> _entries = [];
  bool _loading = true;

  List<DiaryEntry> get entries => _entries;
  bool get loading => _loading;

  Future<void> loadEntries() async {
    _loading = true;
    notifyListeners();
    _entries = await _db.getAllEntries();
    _loading = false;
    notifyListeners();
  }

  Future<void> searchEntries(String query) async {
    _loading = true;
    notifyListeners();
    if (query.isEmpty) {
      _entries = await _db.getAllEntries();
    } else {
      _entries = await _db.searchEntries(query);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addEntry(DiaryEntry entry) async {
    await _db.insertEntry(entry);
    _entries.insert(0, entry);
    notifyListeners();
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    await _db.updateEntry(entry);
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    await _db.deleteEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  DiaryEntry? getEntry(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DiaryEntry> getEntriesByRange(DateTime start, DateTime end) {
    return _entries.where((e) {
      return e.createdAt.isAfter(start.subtract(const Duration(days: 1))) &&
          e.createdAt.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
}

class AIConfigStore extends ChangeNotifier {
  final SettingsService _settings = SettingsService();
  AIConfig _config = AIConfig();
  AIService? _aiService;

  AIConfig get config => _config;
  AIService? get aiService => _aiService;

  Future<void> loadConfig() async {
    _config = await _settings.loadConfig();
    _rebuildAIService();
    notifyListeners();
  }

  Future<void> saveConfig(AIConfig config) async {
    _config = config;
    await _settings.saveConfig(config);
    _rebuildAIService();
    notifyListeners();
  }

  void _rebuildAIService() {
    _aiService?.dispose();
    if (_config.isConfigured) {
      _aiService = AIService(_config);
    } else {
      _aiService = null;
    }
  }
}
