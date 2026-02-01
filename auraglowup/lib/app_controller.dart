import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// -------------------- Data model + Controller --------------------
enum RoutineCategory { fitness, skin, mind }
enum GoalType { habit, progress }

class RoutineTemplate {
  final String id;
  final RoutineCategory category;
  final String title;
  final int minutes;
  final bool enabled;

  RoutineTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.minutes,
    required this.enabled,
  });

  RoutineTemplate copyWith({
    RoutineCategory? category,
    String? title,
    int? minutes,
    bool? enabled,
  }) {
    return RoutineTemplate(
      id: id,
      category: category ?? this.category,
      title: title ?? this.title,
      minutes: minutes ?? this.minutes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'title': title,
        'minutes': minutes,
        'enabled': enabled,
      };

  static RoutineTemplate fromJson(Map<String, dynamic> m) => RoutineTemplate(
        id: m['id'],
        category: RoutineCategory.values.firstWhere(
          (e) => e.name == (m['category'] ?? 'fitness'),
        ),
        title: m['title'] ?? '',
        minutes: (m['minutes'] ?? 20) as int,
        enabled: (m['enabled'] ?? true) as bool,
      );
}

class RoutineTask {
  final String id;
  final String? templateId;
  final RoutineCategory category;
  final String title;
  final int minutes;
  final bool done;

  RoutineTask({
    required this.id,
    required this.templateId,
    required this.category,
    required this.title,
    required this.minutes,
    required this.done,
  });

  RoutineTask copyWith({
    RoutineCategory? category,
    String? title,
    int? minutes,
    bool? done,
  }) {
    return RoutineTask(
      id: id,
      templateId: templateId,
      category: category ?? this.category,
      title: title ?? this.title,
      minutes: minutes ?? this.minutes,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'category': category.name,
        'title': title,
        'minutes': minutes,
        'done': done,
      };

  static RoutineTask fromJson(Map<String, dynamic> m) => RoutineTask(
        id: m['id'],
        templateId: m['templateId'],
        category: RoutineCategory.values.firstWhere(
          (e) => e.name == (m['category'] ?? 'fitness'),
        ),
        title: m['title'] ?? '',
        minutes: (m['minutes'] ?? 20) as int,
        done: (m['done'] ?? false) as bool,
      );
}

class Goal {
  final String id;
  final GoalType type;
  final RoutineCategory category;
  final String title;
  final double target;
  final double current;
  final Set<String> habitDays;

  Goal({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.target,
    required this.current,
    required this.habitDays,
  });

  Goal copyWith({
    GoalType? type,
    RoutineCategory? category,
    String? title,
    double? target,
    double? current,
    Set<String>? habitDays,
  }) {
    return Goal(
      id: id,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      target: target ?? this.target,
      current: current ?? this.current,
      habitDays: habitDays ?? this.habitDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category.name,
        'title': title,
        'target': target,
        'current': current,
        'habitDays': habitDays.toList(),
      };

  static Goal fromJson(Map<String, dynamic> m) => Goal(
        id: m['id'],
        type: GoalType.values.firstWhere(
          (e) => e.name == (m['type'] ?? 'habit'),
        ),
        category: RoutineCategory.values.firstWhere(
          (e) => e.name == (m['category'] ?? 'mind'),
        ),
        title: m['title'] ?? '',
        target: (m['target'] ?? 30).toDouble(),
        current: (m['current'] ?? 0).toDouble(),
        habitDays: ((m['habitDays'] as List?) ?? [])
            .map((e) => e.toString())
            .toSet(),
      );
}

/// Daily checks model (Skin/Fuel + Meditation check)
class DailyChecks {
  final int waterCups;
  final bool sugarFree;
  final bool protein;
  final bool carbsOk;
  final bool vitamins;
  final bool sunlight;
  final bool meditation;

  const DailyChecks({
    required this.waterCups,
    required this.sugarFree,
    required this.protein,
    required this.carbsOk,
    required this.vitamins,
    required this.sunlight,
    required this.meditation,
  });

  static const goalCups = 8;

  DailyChecks copyWith({
    int? waterCups,
    bool? sugarFree,
    bool? protein,
    bool? carbsOk,
    bool? vitamins,
    bool? sunlight,
    bool? meditation,
  }) {
    return DailyChecks(
      waterCups: waterCups ?? this.waterCups,
      sugarFree: sugarFree ?? this.sugarFree,
      protein: protein ?? this.protein,
      carbsOk: carbsOk ?? this.carbsOk,
      vitamins: vitamins ?? this.vitamins,
      sunlight: sunlight ?? this.sunlight,
      meditation: meditation ?? this.meditation,
    );
  }

  Map<String, dynamic> toJson() => {
        'waterCups': waterCups,
        'sugarFree': sugarFree,
        'protein': protein,
        'carbsOk': carbsOk,
        'vitamins': vitamins,
        'sunlight': sunlight,
        'meditation': meditation,
      };

  static DailyChecks fromJson(Map<String, dynamic> m) => DailyChecks(
        waterCups: (m['waterCups'] ?? 0) as int,
        sugarFree: (m['sugarFree'] ?? false) as bool,
        protein: (m['protein'] ?? false) as bool,
        carbsOk: (m['carbsOk'] ?? false) as bool,
        vitamins: (m['vitamins'] ?? false) as bool,
        sunlight: (m['sunlight'] ?? false) as bool,
        meditation: (m['meditation'] ?? false) as bool,
      );

  static const empty = DailyChecks(
    waterCups: 0,
    sugarFree: false,
    protein: false,
    carbsOk: false,
    vitamins: false,
    sunlight: false,
    meditation: false,
  );
}

/// Fitness session per day (Level Start system)
class FitnessSession {
  final int level;
  final bool completed;
  final int xp;
  const FitnessSession({
    required this.level,
    required this.completed,
    required this.xp,
  });

  static const empty = FitnessSession(level: 1, completed: false, xp: 0);

  FitnessSession copyWith({int? level, bool? completed, int? xp}) {
    return FitnessSession(
      level: level ?? this.level,
      completed: completed ?? this.completed,
      xp: xp ?? this.xp,
    );
  }

  Map<String, dynamic> toJson() => {'level': level, 'completed': completed, 'xp': xp};

  static FitnessSession fromJson(Map<String, dynamic> m) => FitnessSession(
        level: (m['level'] ?? 1) as int,
        completed: (m['completed'] ?? false) as bool,
        xp: (m['xp'] ?? 0) as int,
      );
}

class AppState {
  final String? localeCode;
  final String? displayName;

  final List<RoutineTemplate> templates;
  final Map<String, List<RoutineTask>> tasksByDay;
  final List<Goal> goals;
  final Map<String, DailyChecks> checksByDay;

  final Map<String, FitnessSession> fitnessByDay;

  AppState({
    required this.localeCode,
    required this.displayName,
    required this.templates,
    required this.tasksByDay,
    required this.goals,
    required this.checksByDay,
    required this.fitnessByDay,
  });

  Map<String, dynamic> toJson() => {
        'localeCode': localeCode,
        'displayName': displayName,
        'templates': templates.map((e) => e.toJson()).toList(),
        'tasksByDay': tasksByDay.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'goals': goals.map((e) => e.toJson()).toList(),
        'checksByDay': checksByDay.map((k, v) => MapEntry(k, v.toJson())),
        'fitnessByDay': fitnessByDay.map((k, v) => MapEntry(k, v.toJson())),
      };

  static AppState fromJson(Map<String, dynamic> m) {
    final templates = ((m['templates'] as List?) ?? [])
        .map((e) => RoutineTemplate.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final tbd = <String, List<RoutineTask>>{};
    final raw = (m['tasksByDay'] as Map?) ?? {};
    for (final entry in raw.entries) {
      final k = entry.key.toString();
      final list = (entry.value as List?) ?? [];
      tbd[k] = list.map((e) => RoutineTask.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    final goals = ((m['goals'] as List?) ?? [])
        .map((e) => Goal.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final cbd = <String, DailyChecks>{};
    final rawChecks = (m['checksByDay'] as Map?) ?? {};
    for (final e in rawChecks.entries) {
      cbd[e.key.toString()] = DailyChecks.fromJson(Map<String, dynamic>.from(e.value));
    }

    final fbd = <String, FitnessSession>{};
    final rawFitness = (m['fitnessByDay'] as Map?) ?? {};
    for (final e in rawFitness.entries) {
      fbd[e.key.toString()] = FitnessSession.fromJson(Map<String, dynamic>.from(e.value));
    }

    return AppState(
      localeCode: m['localeCode'],
      displayName: m['displayName'],
      templates: templates,
      tasksByDay: tbd,
      goals: goals,
      checksByDay: cbd,
      fitnessByDay: fbd,
    );
  }

  static AppState fresh() {
    final id = _id();
    final baseTemplates = [
      RoutineTemplate(id: '${id}_t1', category: RoutineCategory.fitness, title: 'Gym / Walk', minutes: 35, enabled: true),
      RoutineTemplate(id: '${id}_t2', category: RoutineCategory.skin, title: 'Skin care', minutes: 10, enabled: true),
      RoutineTemplate(id: '${id}_t3', category: RoutineCategory.mind, title: 'Mind reset', minutes: 8, enabled: true),
    ];

    return AppState(
      localeCode: null,
      displayName: '',
      templates: baseTemplates,
      tasksByDay: {},
      goals: [
        Goal(
          id: '${id}_g1',
          type: GoalType.habit,
          category: RoutineCategory.mind,
          title: 'Meditation',
          target: 0,
          current: 0,
          habitDays: <String>{},
        ),
        Goal(
          id: '${id}_g2',
          type: GoalType.progress,
          category: RoutineCategory.fitness,
          title: 'Workouts this month',
          target: 20,
          current: 0,
          habitDays: <String>{},
        ),
      ],
      checksByDay: {},
      fitnessByDay: {},
    );
  }
}

class AppController extends ChangeNotifier {
  static const _prefKey = 'aura_glowup_state_v3';
  final SharedPreferences _prefs;

  AppState state;

  AppController._(this._prefs, this.state);

  static Future<AppController> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);

    late AppState st;
    if (raw == null) {
      st = AppState.fresh();
    } else {
      try {
        st = AppState.fromJson(jsonDecode(raw));
      } catch (_) {
        st = AppState.fresh();
      }
    }

    final c = AppController._(prefs, st);
    await c.ensureDay(_onlyDate(DateTime.now()));
    return c;
  }

  Future<void> _save() async {
    await _prefs.setString(_prefKey, jsonEncode(state.toJson()));
  }

  Future<void> setLocale(String code) async {
    state = AppState(
      localeCode: code,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    state = AppState(
      localeCode: state.localeCode,
      displayName: name,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  /// Generate tasks for a day from enabled templates (idempotent)
  Future<void> ensureDay(DateTime day) async {
    final key = _dayKey(day);
    final existing = state.tasksByDay[key] ?? [];

    final byTemplate = <String, RoutineTask>{};
    for (final t in existing) {
      if (t.templateId != null) byTemplate[t.templateId!] = t;
    }

    var changed = false;
    final next = List<RoutineTask>.from(existing);

    for (final tpl in state.templates.where((t) => t.enabled)) {
      if (byTemplate.containsKey(tpl.id)) continue;
      next.add(
        RoutineTask(
          id: _id(),
          templateId: tpl.id,
          category: tpl.category,
          title: tpl.title,
          minutes: tpl.minutes,
          done: false,
        ),
      );
      changed = true;
    }

    if (changed) {
      final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
      tbd[key] = next;
      state = AppState(
        localeCode: state.localeCode,
        displayName: state.displayName,
        templates: state.templates,
        tasksByDay: tbd,
        goals: state.goals,
        checksByDay: state.checksByDay,
        fitnessByDay: state.fitnessByDay,
      );
      await _save();
      notifyListeners();
    }
  }

  // ----- Daily checks -----
  DailyChecks checksForDay(String dayKey) => state.checksByDay[dayKey] ?? DailyChecks.empty;

  Future<void> _setChecks(String dayKey, DailyChecks next) async {
    final map = Map<String, DailyChecks>.from(state.checksByDay);
    map[dayKey] = next;
    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: state.goals,
      checksByDay: map,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  Future<void> bumpWater(String dayKey, int delta) async {
    final cur = checksForDay(dayKey);
    final raw = cur.waterCups + delta;
    final safe = raw < 0 ? 0 : (raw > 12 ? 12 : raw);
    await _setChecks(dayKey, cur.copyWith(waterCups: safe));
  }

  /// ✅ toggle yerine “set” (Aura ödülü gibi yerlerde lazım)
  Future<void> setCheckValue(String dayKey, String key, bool value) async {
    final cur = checksForDay(dayKey);
    DailyChecks next = cur;
    switch (key) {
      case 'sugarFree':
        next = cur.copyWith(sugarFree: value);
        break;
      case 'protein':
        next = cur.copyWith(protein: value);
        break;
      case 'carbsOk':
        next = cur.copyWith(carbsOk: value);
        break;
      case 'vitamins':
        next = cur.copyWith(vitamins: value);
        break;
      case 'sunlight':
        next = cur.copyWith(sunlight: value);
        break;
      case 'meditation':
        next = cur.copyWith(meditation: value);
        break;
    }
    await _setChecks(dayKey, next);
  }

  Future<void> toggleCheck(String dayKey, String key) async {
    final cur = checksForDay(dayKey);
    DailyChecks next = cur;
    switch (key) {
      case 'sugarFree':
        next = cur.copyWith(sugarFree: !cur.sugarFree);
        break;
      case 'protein':
        next = cur.copyWith(protein: !cur.protein);
        break;
      case 'carbsOk':
        next = cur.copyWith(carbsOk: !cur.carbsOk);
        break;
      case 'vitamins':
        next = cur.copyWith(vitamins: !cur.vitamins);
        break;
      case 'sunlight':
        next = cur.copyWith(sunlight: !cur.sunlight);
        break;
      case 'meditation':
        next = cur.copyWith(meditation: !cur.meditation);
        break;
    }
    await _setChecks(dayKey, next);
  }

  double checksScoreForDay(String dayKey) {
    final c = checksForDay(dayKey);
    double score = 0;
    final water = (c.waterCups / DailyChecks.goalCups).clamp(0.0, 1.0).toDouble();
    score += water * 0.40;
    final toggles = [c.sugarFree, c.protein, c.carbsOk, c.vitamins, c.sunlight, c.meditation];
    final hits = toggles.where((x) => x).length / toggles.length;
    score += hits * 0.60;
    return score.clamp(0.0, 1.0).toDouble();
  }

  // ----- Fitness session -----
  FitnessSession fitnessForDay(String dayKey) => state.fitnessByDay[dayKey] ?? FitnessSession.empty;

  Future<void> _setFitness(String dayKey, FitnessSession sess) async {
    final map = Map<String, FitnessSession>.from(state.fitnessByDay);
    map[dayKey] = sess;
    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: map,
    );
    await _save();
    notifyListeners();
  }

  int recommendedFitnessLevel(String dayKey) {
    // Based on aura score; 1..7
    final aura = auraScoreForDay(dayKey);
    final lvl = 1 + (aura * 6).round();
    return lvl.clamp(1, 7);
  }

  Future<void> completeFitnessLevel(String dayKey, {required int level, required int xp}) async {
    // 1) add quick set tasks (if missing)
    await addQuickWorkoutSet(dayKey);

    // 2) mark those quick tasks done
    await _markQuickWorkoutDone(dayKey);

    // 3) bump first fitness progress goal by +1 (if exists)
    await _bumpFirstFitnessProgressGoal();

    // 4) save session
    await _setFitness(dayKey, FitnessSession(level: level, completed: true, xp: xp));
  }

  Future<void> _bumpFirstFitnessProgressGoal() async {
    final goals = List<Goal>.from(state.goals);
    final idx = goals.indexWhere((g) => g.type == GoalType.progress && g.category == RoutineCategory.fitness);
    if (idx < 0) return;
    goals[idx] = goals[idx].copyWith(current: max(0.0, goals[idx].current + 1));
    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  Future<void> _markQuickWorkoutDone(String dayKey) async {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);
    if (list.isEmpty) return;

    final targets = <String>{
      '20 push-ups',
      '30 sit-ups',
      'plank (60s)',
      '40 squats',
    };

    for (int i = 0; i < list.length; i++) {
      final t = list[i];
      final key = t.title.toLowerCase().trim();
      if (targets.contains(key)) {
        list[i] = t.copyWith(done: true);
      }
    }

    final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
    tbd[dayKey] = list;

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: tbd,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  // ----- Tasks -----
  List<RoutineTask> tasksForDay(String dayKey) {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.category.index.compareTo(b.category.index);
    });
    return list;
  }

  int doneCountForDay(String dayKey) => tasksForDay(dayKey).where((t) => t.done).length;

  double completionForDay(String dayKey) {
    final list = tasksForDay(dayKey);
    if (list.isEmpty) return 0;
    final done = list.where((t) => t.done).length;
    return done / list.length;
  }

  /// Aura score = 55% task completion + 30% goals score + 15% checks score
  double auraScoreForDay(String dayKey) {
    final completion = completionForDay(dayKey);
    final goalsScore = goalsScoreForDay(dayKey);
    final checksScore = checksScoreForDay(dayKey);
    return (completion * 0.55 + goalsScore * 0.30 + checksScore * 0.15).clamp(0.0, 1.0).toDouble();
  }

  double goalsScoreForDay(String dayKey) {
    if (state.goals.isEmpty) return 0;
    double sum = 0;
    for (final g in state.goals) {
      if (g.type == GoalType.progress) {
        final ratio = g.target <= 0 ? 0.0 : (g.current / g.target).clamp(0, 1);
        sum += ratio;
      } else {
        final todayHit = g.habitDays.contains(dayKey) ? 1.0 : 0.0;
        final last7 = _last7Keys(_onlyDate(DateTime.now()));
        final hits = last7.where((k) => g.habitDays.contains(k)).length / 7.0;
        sum += (todayHit * 0.55 + hits * 0.45);
      }
    }
    return (sum / state.goals.length).clamp(0.0, 1.0).toDouble();
  }

  Future<void> toggleTask(String dayKey, String taskId) async {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);
    final idx = list.indexWhere((e) => e.id == taskId);
    if (idx < 0) return;

    list[idx] = list[idx].copyWith(done: !list[idx].done);

    final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
    tbd[dayKey] = list;

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: tbd,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  Future<void> addTaskForDay(String dayKey, {required RoutineCategory category, required String title, required int minutes}) async {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);
    list.add(RoutineTask(id: _id(), templateId: null, category: category, title: title, minutes: minutes, done: false));

    final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
    tbd[dayKey] = list;

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: tbd,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  Future<void> editTask(String dayKey, String taskId, {required RoutineCategory category, required String title, required int minutes}) async {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);
    final idx = list.indexWhere((e) => e.id == taskId);
    if (idx < 0) return;

    list[idx] = list[idx].copyWith(category: category, title: title, minutes: minutes);

    final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
    tbd[dayKey] = list;

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: tbd,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  Future<void> deleteTask(String dayKey, String taskId) async {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);
    list.removeWhere((e) => e.id == taskId);

    final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
    tbd[dayKey] = list;

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: tbd,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  /// Add template (daily) + ensure day includes it
  Future<void> addTemplateAndEnsure(String dayKey, {required RoutineCategory category, required String title, required int minutes}) async {
    final tpl = RoutineTemplate(id: _id(), category: category, title: title, minutes: minutes, enabled: true);
    final templates = List<RoutineTemplate>.from(state.templates)..add(tpl);

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: templates,
      tasksByDay: state.tasksByDay,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();

    await ensureDay(_fromDayKey(dayKey));
  }

  /// Quick workout set (fitness)
  Future<void> addQuickWorkoutSet(String dayKey) async {
    final list = List<RoutineTask>.from(state.tasksByDay[dayKey] ?? []);

    bool existsTitle(String t) => list.any((x) => x.title.toLowerCase().trim() == t.toLowerCase().trim());

    void addIfMissing(String title, int minutes) {
      if (existsTitle(title)) return;
      list.add(
        RoutineTask(
          id: _id(),
          templateId: null,
          category: RoutineCategory.fitness,
          title: title,
          minutes: minutes,
          done: false,
        ),
      );
    }

    addIfMissing('20 Push-ups', 4);
    addIfMissing('30 Sit-ups', 5);
    addIfMissing('Plank (60s)', 3);
    addIfMissing('40 Squats', 6);

    final tbd = Map<String, List<RoutineTask>>.from(state.tasksByDay);
    tbd[dayKey] = list;

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: tbd,
      goals: state.goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  /// Goals
  Future<void> addGoal({
    required String title,
    required GoalType type,
    required RoutineCategory category,
    required double target,
    required double current,
  }) async {
    final goals = List<Goal>.from(state.goals)
      ..add(
        Goal(
          id: _id(),
          type: type,
          category: category,
          title: title,
          target: target,
          current: current,
          habitDays: <String>{},
        ),
      );

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  Future<void> editGoal(
    String goalId, {
    required String title,
    required GoalType type,
    required RoutineCategory category,
    required double target,
    required double current,
  }) async {
    final goals = List<Goal>.from(state.goals);
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;

    goals[idx] = goals[idx].copyWith(
      title: title,
      type: type,
      category: category,
      target: target,
      current: current,
      habitDays: goals[idx].habitDays,
    );

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  Future<void> deleteGoal(String goalId) async {
    final goals = List<Goal>.from(state.goals)..removeWhere((g) => g.id == goalId);

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );
    await _save();
    notifyListeners();
  }

  Future<void> toggleHabitDay(String goalId, String dayKey) async {
    final goals = List<Goal>.from(state.goals);
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;

    final g = goals[idx];
    final set = Set<String>.from(g.habitDays);
    if (set.contains(dayKey)) {
      set.remove(dayKey);
    } else {
      set.add(dayKey);
    }

    goals[idx] = g.copyWith(habitDays: set);

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  Future<void> bumpGoalProgress(String goalId, double delta) async {
    final goals = List<Goal>.from(state.goals);
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;

    final g = goals[idx];
    if (g.type != GoalType.progress) return;

    final next = g.current + delta;
    final safe = next < 0 ? 0.0 : next;
    goals[idx] = g.copyWith(current: safe);

    state = AppState(
      localeCode: state.localeCode,
      displayName: state.displayName,
      templates: state.templates,
      tasksByDay: state.tasksByDay,
      goals: goals,
      checksByDay: state.checksByDay,
      fitnessByDay: state.fitnessByDay,
    );

    await _save();
    notifyListeners();
  }

  /// Streak logic:
  /// A day counts as success if completion >= 0.60 AND that day has at least 1 task.
  StreakStats streakStats(DateTime today) {
    int current = 0;

    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final k = _dayKey(d);
      if (_isSuccessDay(k)) {
        current += 1;
      } else {
        break;
      }
    }

    int best = 0;
    int run = 0;
    for (int i = 364; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final k = _dayKey(d);
      if (_isSuccessDay(k)) {
        run += 1;
        best = max(best, run);
      } else {
        run = 0;
      }
    }

    return StreakStats(current: current, best: best);
  }

  bool _isSuccessDay(String dayKey) {
    final list = state.tasksByDay[dayKey] ?? const <RoutineTask>[];
    if (list.isEmpty) return false;
    final comp = completionForDay(dayKey);
    return comp >= 0.60;
  }

  List<DayStat> last7DaysStats(DateTime today) {
    final days = <DayStat>[];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final k = _dayKey(d);
      final comp = completionForDay(k);
      final aura = auraScoreForDay(k);
      final success = _isSuccessDay(k);
      days.add(DayStat(day: d, completion: comp, aura: aura, success: success));
    }
    return days;
  }

  double last7DaysAuraAvg(DateTime today) {
    final stats = last7DaysStats(today);
    if (stats.isEmpty) return 0;
    final sum = stats.fold<double>(0, (a, b) => a + b.aura);
    return (sum / stats.length).clamp(0.0, 1.0).toDouble();
  }

  Future<void> resetAll() async {
    state = AppState.fresh();
    await _save();
    notifyListeners();
  }
}

class StreakStats {
  final int current;
  final int best;
  StreakStats({required this.current, required this.best});
}

class DayStat {
  final DateTime day;
  final double completion;
  final double aura;
  final bool success;
  DayStat({
    required this.day,
    required this.completion,
    required this.aura,
    required this.success,
  });
}

/// -------------------- Helpers (private to this file) --------------------
String _id() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';

DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

String _dayKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime _fromDayKey(String k) {
  final parts = k.split('-');
  if (parts.length != 3) return _onlyDate(DateTime.now());
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

List<String> _last7Keys(DateTime today) => List.generate(7, (i) => _dayKey(today.subtract(Duration(days: i))));
