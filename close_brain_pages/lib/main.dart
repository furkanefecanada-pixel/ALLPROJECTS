import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'iap/iap_service.dart'; // <-- ekle
import 'screens/third_eye_screen.dart';


/// ======================
/// MAIN + APP ROOT
/// ======================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool('has_seen_onboarding') ?? false;

  // IAP init
  await IAPService.I.init();

  runApp(MindClearApp(showOnboarding: !seen));
}

/// COLORS (palette)
const Color kDark = Color(0xFF01161E);
const Color kDeepBlue = Color(0xFF124559);
const Color kBlueGrey = Color(0xFF598392);
const Color kSoftGreen = Color(0xFFAEC3B0);
const Color kLight = Color(0xFFEFF6E0);

class MindClearApp extends StatelessWidget {
  final bool showOnboarding;
  const MindClearApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Close Brain Pages',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kSoftGreen,
          primary: kSoftGreen,
          secondary: kBlueGrey,
          background: kDark,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kLight),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kDark,
          foregroundColor: kLight,
          elevation: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: showOnboarding ? const WelcomeScreen() : const SplashGate(),
    );
  }
}

/// ======================
/// SPLASH SCREEN (her açılışta 2s)
/// ======================

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scale = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _rotation = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MindHomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: Stack(
        children: [
          // Hafif arka plan dekoru
          Align(
            alignment: const Alignment(-1.2, -1.1),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: kDeepBlue.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(1.1, 1.2),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: kSoftGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Transform.rotate(
                      angle: _rotation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  // Beyin + sayfa hissi
                  Icon(
                    Icons.menu_book_rounded,
                    size: 72,
                    color: kSoftGreen,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Close Brain Pages",
                    style: TextStyle(
                      color: kLight,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Clear today’s mental pages",
                    style: TextStyle(
                      color: kSoftGreen,
                      fontSize: 14,
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
}

/// ======================
/// MODELLER
/// ======================

class ThoughtEntry {
  final String text;
  final String? solution; // opsiyonel çözüm
  final DateTime createdAt;

  ThoughtEntry({
    required this.text,
    required this.createdAt,
    this.solution,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'solution': solution,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ThoughtEntry.fromMap(Map<String, dynamic> map) {
    return ThoughtEntry(
      text: map['text'] as String,
      solution: map['solution'] as String?, // eski datada yoksa null
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class MoodEntry {
  final int moodId; // aşağıdaki options listesine göre id
  final DateTime createdAt;

  MoodEntry({
    required this.moodId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'moodId': moodId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      moodId: map['moodId'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class MoodOption {
  final int id;
  final String emoji;
  final String label;
  final int score; // -2 çok kötü, +2 çok iyi

  const MoodOption({
    required this.id,
    required this.emoji,
    required this.label,
    required this.score,
  });
}

/// Mood seçenekleri (12 tane)
const List<MoodOption> kMoodOptions = [
  MoodOption(id: 1, emoji: "😭", label: "Broken", score: -2),
  MoodOption(id: 2, emoji: "😢", label: "Very sad", score: -2),
  MoodOption(id: 3, emoji: "☹️", label: "Sad", score: -1),
  MoodOption(id: 4, emoji: "😟", label: "Anxious", score: -1),
  MoodOption(id: 5, emoji: "😐", label: "Neutral", score: 0),
  MoodOption(id: 6, emoji: "😶‍🌫️", label: "Empty", score: 0),
  MoodOption(id: 7, emoji: "🙂", label: "Okay", score: 1),
  MoodOption(id: 8, emoji: "😊", label: "Good", score: 1),
  MoodOption(id: 9, emoji: "😄", label: "Happy", score: 2),
  MoodOption(id: 10, emoji: "🤩", label: "Excited", score: 2),
  MoodOption(id: 11, emoji: "😤", label: "Angry", score: -1),
  MoodOption(id: 12, emoji: "😴", label: "Tired", score: -1),
];

MoodOption? getMoodOptionById(int id) {
  try {
    return kMoodOptions.firstWhere((m) => m.id == id);
  } catch (_) {
    return null;
  }
}

/// ======================
/// HOME SCREEN
/// ======================

class MindHomeScreen extends StatefulWidget {
  const MindHomeScreen({super.key});

  @override
  State<MindHomeScreen> createState() => _MindHomeScreenState();
}

class _MindHomeScreenState extends State<MindHomeScreen> {
  final List<ThoughtEntry> _thoughts = [];
  final List<MoodEntry> _moods = [];

  bool _isLoading = true;
  int _selectedTab = 0; // 0: Today, 1: History, 2: Activity
  bool _moodAskedThisSession = false;

  // gamification state
  int _totalPoints = 0;
  int _totalThoughts = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  String? _lastDayKey; // yyyy-MM-dd
  String? _lastGoalCompletedDayKey;

  bool _showCelebration = false; // günlük hedef kutlama overlay

  // keys
  static const String _thoughtsKey = 'thoughts_v1';
  static const String _pointsKey = 'points_v1';
  static const String _totalThoughtsKey = 'total_thoughts_v1';
  static const String _currentStreakKey = 'current_streak_v1';
  static const String _bestStreakKey = 'best_streak_v1';
  static const String _lastDayKeyKey = 'last_day_key_v1';
  static const String _lastGoalDayKey = 'last_goal_day_key_v1';

  static const String _moodsKey = 'moods_v1';

  // sabitler (günlük goal)
  static const int _pointsPerThought = 10;
  static const int _dailyGoalBase = 5;
  static const int _dailyGoalBonus = 50;

  final List<String> _simplePrompts = const [
    "What is worrying you right now?",
    "Is there money or work stress in your head?",
    "Is someone not messaging you and you keep thinking about it?",
    "Did you feel sad, angry or guilty today?",
    "What do you think you did wrong today?",
    "What are you afraid of tomorrow?",
    "Is there something you cannot control but still think about?",
    "Is there something you want to forgive yourself for?",
    "Is there something about your body or face you keep thinking about?",
    "Is there a mistake from the past that comes back in your mind?",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ------------ LOAD & SAVE ------------

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final thoughtsJson = prefs.getStringList(_thoughtsKey) ?? [];
    final moodsJson = prefs.getStringList(_moodsKey) ?? [];

    final loadedThoughts = thoughtsJson
        .map((e) => ThoughtEntry.fromMap(jsonDecode(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final loadedMoods = moodsJson
        .map((e) => MoodEntry.fromMap(jsonDecode(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _thoughts
        ..clear()
        ..addAll(loadedThoughts);

      _moods
        ..clear()
        ..addAll(loadedMoods);

      _totalPoints = prefs.getInt(_pointsKey) ?? 0;
      _totalThoughts = prefs.getInt(_totalThoughtsKey) ?? loadedThoughts.length;
      _currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      _bestStreak = prefs.getInt(_bestStreakKey) ?? 0;
      _lastDayKey = prefs.getString(_lastDayKeyKey);
      _lastGoalCompletedDayKey = prefs.getString(_lastGoalDayKey);
      _isLoading = false;
    });

    // app açıldığında mood sor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askMoodIfNeeded();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedThoughts = _thoughts.map((t) => jsonEncode(t.toMap())).toList();
    final encodedMoods = _moods.map((m) => jsonEncode(m.toMap())).toList();

    await prefs.setStringList(_thoughtsKey, encodedThoughts);
    await prefs.setStringList(_moodsKey, encodedMoods);

    await prefs.setInt(_pointsKey, _totalPoints);
    await prefs.setInt(_totalThoughtsKey, _totalThoughts);
    await prefs.setInt(_currentStreakKey, _currentStreak);
    await prefs.setInt(_bestStreakKey, _bestStreak);

    if (_lastDayKey != null) {
      await prefs.setString(_lastDayKeyKey, _lastDayKey!);
    }
    if (_lastGoalCompletedDayKey != null) {
      await prefs.setString(_lastGoalDayKey, _lastGoalCompletedDayKey!);
    }
  }

  // ------------ HELPERS ------------

  String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  int get _todayThoughtCount {
    final now = DateTime.now();
    return _thoughts
        .where((t) =>
            t.createdAt.year == now.year &&
            t.createdAt.month == now.month &&
            t.createdAt.day == now.day)
        .length;
  }

  MoodEntry? get _todayLastMood {
    final now = DateTime.now();
    for (final m in _moods) {
      if (m.createdAt.year == now.year &&
          m.createdAt.month == now.month &&
          m.createdAt.day == now.day) {
        return m;
      }
    }
    return null;
  }

  int? get _todayMoodScore {
    final mood = _todayLastMood;
    if (mood == null) return null;
    final option = getMoodOptionById(mood.moodId);
    return option?.score;
  }

  MoodOption? get _todayMoodOption {
    final mood = _todayLastMood;
    if (mood == null) return null;
    return getMoodOptionById(mood.moodId);
  }

  int get _recommendedThoughts {
    final score = _todayMoodScore;
    if (score == null) return _dailyGoalBase;

    if (score >= 2) return 3; // çok iyi
    if (score == 1) return 4;
    if (score == 0) return 5;
    if (score == -1) return 7;
    return 9; // -2 çok kötü
  }

  int get _dailyGoal {
    return _dailyGoalBase;
  }

  double get _todayProgress {
    final c = _todayThoughtCount;
    if (c == 0) return 0;
    final p = c / _dailyGoal;
    return p > 1 ? 1 : p;
  }

  String get _motivationText {
    final moodOpt = _todayMoodOption;
    final rec = _recommendedThoughts;

    if (_todayThoughtCount == 0) {
      if (moodOpt == null) {
        return "Start by writing 1 thought from your head.";
      } else {
        return "You feel ${moodOpt.label.toLowerCase()}. Start with 1 thought and try to write $rec today.";
      }
    } else if (_todayThoughtCount < _dailyGoal) {
      final left = _dailyGoal - _todayThoughtCount;
      return "Good. Write $left more thoughts to close today’s page.";
    } else {
      if (moodOpt == null) {
        return "Nice. Today’s page is closed. You can still write more.";
      } else {
        return "Nice. With your current mood (${moodOpt.emoji} ${moodOpt.label}), keep writing if your head is not calm yet.";
      }
    }
  }

  String get _moodSuggestionText {
    final moodOpt = _todayMoodOption;
    final rec = _recommendedThoughts;

    if (moodOpt == null) {
      return "Select how you feel now. The app will suggest how many thoughts to write.";
    }

    if (moodOpt.score >= 2) {
      return "You feel very good (${moodOpt.emoji} ${moodOpt.label}). Writing around $rec short thoughts is enough to keep your mind clear.";
    } else if (moodOpt.score == 1) {
      return "You feel okay (${moodOpt.emoji} ${moodOpt.label}). Try to write $rec thoughts and add solutions if needed.";
    } else if (moodOpt.score == 0) {
      return "You feel neutral (${moodOpt.emoji} ${moodOpt.label}). Write at least $rec thoughts that are stuck in your head.";
    } else if (moodOpt.score == -1) {
      return "You feel low (${moodOpt.emoji} ${moodOpt.label}). Aim for about $rec thoughts and try to write a solution for each important one.";
    } else {
      return "You feel very low (${moodOpt.emoji} ${moodOpt.label}). Try to write $rec thoughts and write a solution or small action under each one.";
    }
  }

  int get _level {
    return (_totalPoints ~/ 100) + 1;
  }

  String get _title {
    if (_totalPoints < 100) {
      return "Mind Beginner";
    } else if (_totalPoints < 300) {
      return "Page Closer";
    } else if (_totalPoints < 700) {
      return "Deep Cleaner";
    } else {
      return "Calm Brain Master";
    }
  }

  // ------------ GAMIFICATION LOGIC ------------

  void _updateStreakForNewThought() {
    final today = _todayKey();

    if (_lastDayKey == today) {
      return;
    }

    if (_lastDayKey == null) {
      _currentStreak = 1;
      _bestStreak = 1;
      _lastDayKey = today;
      return;
    }

    final lastDate = DateTime.parse(_lastDayKey!);
    final now = DateTime.now();
    final diff = now
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;

    if (diff == 1) {
      _currentStreak += 1;
    } else {
      _currentStreak = 1;
    }

    if (_currentStreak > _bestStreak) {
      _bestStreak = _currentStreak;
    }

    _lastDayKey = today;
  }

  Future<void> _checkDailyGoalBonus() async {
    final today = _todayKey();

    if (_todayThoughtCount >= _dailyGoal &&
        _lastGoalCompletedDayKey != today) {
      setState(() {
        _totalPoints += _dailyGoalBonus;
        _lastGoalCompletedDayKey = today;
        _showCelebration = true;
      });

      await _saveData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kDeepBlue,
          content: Text(
            "Daily page closed 🎉 +$_dailyGoalBonus bonus points!",
            style: const TextStyle(color: kLight),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _showCelebration = false;
      });
    }
  }

  // ------------ MOOD FLOW ------------

  Future<void> _askMoodIfNeeded() async {
    if (_moodAskedThisSession) return;
    _moodAskedThisSession = true;

    await _showMoodBottomSheet();
  }

  Future<void> _showMoodBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kBlueGrey,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                "How do you feel right now?",
                style: TextStyle(
                  color: kLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select one emoji. Your mood will be saved in history.",
                style: TextStyle(
                  color: kSoftGreen,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: kMoodOptions.map((opt) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _setMood(opt.id);
                      Navigator.of(ctx).pop();
                    },
                    splashColor: kSoftGreen.withOpacity(0.2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: kDeepBlue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kSoftGreen.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opt.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt.label,
                            style: const TextStyle(
                              color: kLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "Skip for now",
                  style: TextStyle(color: kSoftGreen),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setMood(int moodId) async {
    final entry = MoodEntry(
      moodId: moodId,
      createdAt: DateTime.now(),
    );

    setState(() {
      _moods.insert(0, entry);
    });

    await _saveData();

    if (!mounted) return;

    final opt = getMoodOptionById(moodId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kDeepBlue,
        content: Text(
          opt == null
              ? "Mood saved."
              : "Mood saved: ${opt.emoji} ${opt.label}",
          style: const TextStyle(color: kLight),
        ),
      ),
    );
  }

  // ------------ ADD THOUGHT FLOW (solution dahil) ------------

  Future<void> _addThoughtFlow() async {
    final prompt = (_simplePrompts.toList()..shuffle()).first;
    final thoughtController = TextEditingController();
    final solutionController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: kBlueGrey,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Text(
                  "Write one thought",
                  style: TextStyle(
                    color: kLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prompt,
                  style: const TextStyle(
                    color: kSoftGreen,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: thoughtController,
                  maxLines: 3,
                  style: const TextStyle(color: kLight),
                  decoration: InputDecoration(
                    hintText:
                        "Example: I owe my friend \$500 and I keep thinking about it.",
                    hintStyle: TextStyle(color: kLight.withOpacity(0.5)),
                    filled: true,
                    fillColor: kDeepBlue.withOpacity(0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Optional: Write a solution or action",
                  style: TextStyle(
                    color: kLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: solutionController,
                  maxLines: 3,
                  style: const TextStyle(color: kLight),
                  decoration: InputDecoration(
                    hintText:
                        "Example: I will pay \$100 every month and tell my friend my plan.",
                    hintStyle: TextStyle(color: kLight.withOpacity(0.5)),
                    filled: true,
                    fillColor: kDeepBlue.withOpacity(0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSoftGreen,
                      foregroundColor: kDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      final text = thoughtController.text.trim();
                      if (text.isEmpty) return;
                      final sol = solutionController.text.trim();
                      Navigator.of(ctx).pop({
                        'thought': text,
                        'solution': sol,
                      });
                    },
                    child: const Text(
                      "Save thought",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;

    final text = result['thought']?.trim() ?? '';
    if (text.isEmpty) return;

    final sol = result['solution']?.trim();
    final newEntry = ThoughtEntry(
      text: text,
      solution: sol?.isEmpty ?? true ? null : sol,
      createdAt: DateTime.now(),
    );

    setState(() {
      _thoughts.insert(0, newEntry);
      _totalThoughts += 1;
      _totalPoints += _pointsPerThought;
      _updateStreakForNewThought();
    });

    await _saveData();

    if (!mounted) return;

    final praiseMessages = [
      "Nice. +$_pointsPerThought points for clearing your mind.",
      "Good job. You closed one more small page.",
      "Your brain is lighter now. +$_pointsPerThought points.",
    ];

    praiseMessages.shuffle();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kDeepBlue,
        content: Text(
          praiseMessages.first,
          style: const TextStyle(color: kLight),
        ),
      ),
    );

    await _checkDailyGoalBonus();
  }

  // ------------ UI ------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kSoftGreen),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const SizedBox(), // boş, app adı yazmıyor
            elevation: 0,
            centerTitle: false,
            backgroundColor: kDark,
            actions: [
              IconButton(
                onPressed: _showMoodBottomSheet,
                icon: const Icon(Icons.mood, color: kLight),
                tooltip: "Update mood",
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildBodyForTab(),
          ),
          floatingActionButton: _selectedTab == 0
              ? FloatingActionButton.extended(
                  backgroundColor: kSoftGreen,
                  foregroundColor: kDark,
                  onPressed: _addThoughtFlow,
                  label: const Text(
                    "Add thought",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.edit),
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: kDark,
            selectedItemColor: kSoftGreen,
            unselectedItemColor: kLight.withOpacity(0.6),
            currentIndex: _selectedTab,
            onTap: (index) {
              setState(() {
                _selectedTab = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Today",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: "History",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights),
                label: "Activity",
              ),
            ],
          ),
        ),

        // Günlük hedef celebration overlay
        if (_showCelebration) _buildCelebrationOverlay(),
      ],
    );
  }

  Widget _buildCelebrationOverlay() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "🎉",
                style: TextStyle(fontSize: 60),
              ),
              SizedBox(height: 8),
              Text(
                "Daily page closed!",
                style: TextStyle(
                  color: kLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "You kept your discipline today.",
                style: TextStyle(
                  color: kSoftGreen,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyForTab() {
    switch (_selectedTab) {
      case 0:
        return _buildTodayPage();
      case 1:
        return _buildHistoryPage();
      case 2:
        return _buildActivityPage();
      default:
        return _buildTodayPage();
    }
  }

  /// --------- TODAY TAB ---------

  Widget _buildTodayPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopStatsCard(),
        const SizedBox(height: 16),
        _buildMoodSuggestionCard(),

      // ✅ NEW CARD
      const SizedBox(height: 12),
      _buildThirdEyeCard(), 

        const SizedBox(height: 20),
        const Text(
          "Today’s thoughts",
          style: TextStyle(
            color: kLight,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildTodayList()),
        

      ],
    );
    
  }

  Widget _buildTopStatsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDeepBlue.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // üst satır: level + title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kDark,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.bubble_chart,
                      color: kSoftGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Level $_level",
                        style: const TextStyle(
                          color: kLight,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _title,
                        style: const TextStyle(
                          color: kSoftGreen,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Total points",
                    style: TextStyle(
                      color: kSoftGreen,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _totalPoints.toString(),
                    style: const TextStyle(
                      color: kLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // progress bar (animasyonlu)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _todayProgress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: kDark,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(kSoftGreen),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _motivationText,
                  style: const TextStyle(
                    color: kLight,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${_todayThoughtCount}/$_dailyGoal",
                style: const TextStyle(
                  color: kLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // streak & total thoughts
          Row(
            children: [
              Expanded(
                child: _smallStat(
                  title: "Current streak",
                  value: "${_currentStreak}d",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallStat(
                  title: "Best streak",
                  value: "${_bestStreak}d",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallStat(
                  title: "Total thoughts",
                  value: _totalThoughts.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSuggestionCard() {
    final moodOpt = _todayMoodOption;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBlueGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kDark,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              moodOpt?.emoji ?? "🧠",
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moodOpt == null
                      ? "How is your mood?"
                      : "Mood: ${moodOpt.emoji} ${moodOpt.label}",
                  style: const TextStyle(
                    color: kLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _moodSuggestionText,
                  style: const TextStyle(
                    color: kLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _showMoodBottomSheet,
                    icon: const Icon(
                      Icons.mood,
                      size: 16,
                      color: kSoftGreen,
                    ),
                    label: const Text(
                      "Update mood",
                      style: TextStyle(
                        color: kSoftGreen,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThirdEyeCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kDeepBlue.withOpacity(0.9),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kDark,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.visibility, color: kSoftGreen),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Open Your Third Eye",
                style: TextStyle(
                  color: kLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Breath exercise + premium meditation.",
                style: TextStyle(color: kSoftGreen, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThirdEyeScreen()),
            );
          },
          child: const Text("Open", style: TextStyle(color: kSoftGreen)),
        ),
      ],
    ),
  );
}


  Widget _smallStat({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: kBlueGrey.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kSoftGreen,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kLight,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayList() {
    final now = DateTime.now();
    final todayThoughts = _thoughts.where((t) {
      return t.createdAt.year == now.year &&
          t.createdAt.month == now.month &&
          t.createdAt.day == now.day;
    }).toList();

    if (todayThoughts.isEmpty) {
      return const Center(
        child: Text(
          "Your head is full.\nWrite your first thought for today.",
          textAlign: TextAlign.center,
          style: TextStyle(color: kLight),
        ),
      );
    }

    return ListView.separated(
      itemCount: todayThoughts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final t = todayThoughts[index];
        final timeText =
            "${t.createdAt.hour.toString().padLeft(2, '0')}:${t.createdAt.minute.toString().padLeft(2, '0')}";

        return Dismissible(
          key: ValueKey(t.createdAt.toIso8601String()),
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          secondaryBackground: Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) async {
            setState(() {
              _thoughts.remove(t);
            });
            await _saveData();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBlueGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kSoftGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.text,
                        style:
                            const TextStyle(color: kLight, fontSize: 14),
                      ),
                      if (t.solution != null && t.solution!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          "Solution:",
                          style: TextStyle(
                            color: kSoftGreen.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.solution!,
                          style: const TextStyle(
                            color: kLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: kLight.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// --------- HISTORY TAB ---------

  Widget _buildHistoryPage() {
    final Map<String, List<ThoughtEntry>> groupedThoughts = {};
    for (final t in _thoughts) {
      final key =
          "${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}-${t.createdAt.day.toString().padLeft(2, '0')}";
      groupedThoughts.putIfAbsent(key, () => []);
      groupedThoughts[key]!.add(t);
    }

    final Map<String, List<MoodEntry>> groupedMoods = {};
    for (final m in _moods) {
      final key =
          "${m.createdAt.year}-${m.createdAt.month.toString().padLeft(2, '0')}-${m.createdAt.day.toString().padLeft(2, '0')}";
      groupedMoods.putIfAbsent(key, () => []);
      groupedMoods[key]!.add(m);
    }

    final allKeys = <String>{
      ...groupedThoughts.keys,
      ...groupedMoods.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a)); // son günler üstte

    if (allKeys.isEmpty) {
      return const Center(
        child: Text(
          "No history yet.\nWrite thoughts and select your mood to see history.",
          textAlign: TextAlign.center,
          style: TextStyle(color: kLight),
        ),
      );
    }

    return ListView.builder(
      itemCount: allKeys.length,
      itemBuilder: (context, index) {
        final dateKey = allKeys[index];
        final dateThoughts = groupedThoughts[dateKey] ?? [];
        final dateMoods = groupedMoods[dateKey] ?? [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateKey,
                style: const TextStyle(
                  color: kSoftGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (dateMoods.isNotEmpty) _buildHistoryMoodsRow(dateMoods),
              if (dateMoods.isNotEmpty && dateThoughts.isNotEmpty)
                const SizedBox(height: 6),
              if (dateThoughts.isNotEmpty)
                ...dateThoughts.map((t) {
                  final timeText =
                      "${t.createdAt.hour.toString().padLeft(2, '0')}:${t.createdAt.minute.toString().padLeft(2, '0')}";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kBlueGrey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.text,
                          style: const TextStyle(
                            color: kLight,
                            fontSize: 14,
                          ),
                        ),
                        if (t.solution != null &&
                            t.solution!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Solution:",
                            style: TextStyle(
                              color: kSoftGreen.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.solution!,
                            style: const TextStyle(
                              color: kLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          timeText,
                          style: TextStyle(
                            color: kLight.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryMoodsRow(List<MoodEntry> moods) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: moods.map((m) {
          final opt = getMoodOptionById(m.moodId);
          final timeText =
              "${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}";
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: kDeepBlue.withOpacity(0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Text(
                  opt?.emoji ?? "🙂",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 4),
                Text(
                  opt?.label ?? "Mood",
                  style: const TextStyle(
                    color: kLight,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeText,
                  style: TextStyle(
                    color: kLight.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// --------- ACTIVITY TAB ---------

  Widget _buildActivityPage() {
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final day = now.subtract(Duration(days: i));
      final key =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

      final thoughtsCount = _thoughts.where((t) {
        return t.createdAt.year == day.year &&
            t.createdAt.month == day.month &&
            t.createdAt.day == day.day;
      }).length;

      final moodsOfDay = _moods.where((m) {
        return m.createdAt.year == day.year &&
            m.createdAt.month == day.month &&
            m.createdAt.day == day.day;
      }).toList();

      return {
        'key': key,
        'thoughts': thoughtsCount,
        'moods': moodsOfDay,
      };
    });

    final totalMoods = _moods.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genel stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kDeepBlue.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overview",
                  style: TextStyle(
                    color: kLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _smallStat(
                        title: "Total thoughts",
                        value: _totalThoughts.toString(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallStat(
                        title: "Saved moods",
                        value: totalMoods.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _smallStat(
                        title: "Current streak",
                        value: "${_currentStreak}d",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallStat(
                        title: "Best streak",
                        value: "${_bestStreak}d",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Last 7 days",
            style: TextStyle(
              color: kLight,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...last7Days.map((dayMap) {
            final key = dayMap['key'] as String;
            final thoughtsCount = dayMap['thoughts'] as int;
            final moodsOfDay = dayMap['moods'] as List<MoodEntry>;

            if (thoughtsCount == 0 && moodsOfDay.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: kDeepBlue.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      key,
                      style: const TextStyle(
                        color: kSoftGreen,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "No activity",
                      style: TextStyle(
                        color: kLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: kBlueGrey.withOpacity(0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      color: kSoftGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "Thoughts: $thoughtsCount",
                        style: const TextStyle(
                          color: kLight,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (moodsOfDay.isNotEmpty)
                        Row(
                          children: [
                            const Text(
                              "Mood:",
                              style: TextStyle(
                                color: kLight,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ...moodsOfDay.take(4).map((m) {
                              final opt = getMoodOptionById(m.moodId);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  opt?.emoji ?? "🙂",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }),
                            if (moodsOfDay.length > 4)
                              const Text(
                                " +",
                                style: TextStyle(
                                  color: kLight,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// ======================
/// WELCOME / ONBOARDING
/// ======================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _goNext(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MindHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Close Brain Pages",
              style: TextStyle(
                color: kLight,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your mind is like a book.\nSome pages stay open all day.",
              style: TextStyle(
                color: kSoftGreen,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "This app helps you:",
              style: TextStyle(
                color: kLight,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const BulletText(
                "Write the thoughts you cannot stop thinking about."),
            const BulletText(
                "See all your thoughts with time in a simple history."),
            const BulletText("Get points and levels when you clear your head."),
            const BulletText(
                "Build a streak: write at least 5 thoughts every day."),
            const SizedBox(height: 24),
            const Text(
              "Examples:",
              style: TextStyle(
                color: kLight,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const BulletText("“I owe my friend \$500 and I feel bad.”"),
            const BulletText(
                "“She is not texting me back and I think about it all day.”"),
            const BulletText(
                "“I did not improve myself today but I will try tomorrow.”"),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSoftGreen,
                  foregroundColor: kDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => _goNext(context),
                child: const Text(
                  "Start clearing my mind",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BulletText extends StatelessWidget {
  final String text;
  const BulletText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(color: kLight, fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: kLight, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}