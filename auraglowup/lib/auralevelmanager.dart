import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuraLevelManager extends ChangeNotifier {
  static const _prefKey = 'aura_glowup_aura_level_v3';

  final SharedPreferences _prefs;

  int _level; // 1..99
  String? _lastCompletedDayKey;

  final Map<String, AuraDayLog> _logsByDay;

  AuraLevelManager._(
    this._prefs, {
    required int level,
    required String? lastCompletedDayKey,
    required Map<String, AuraDayLog> logsByDay,
  })  : _level = level,
        _lastCompletedDayKey = lastCompletedDayKey,
        _logsByDay = logsByDay;

  static Future<AuraLevelManager> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);

    if (raw == null) {
      final fresh = AuraLevelManager._(
        prefs,
        level: 1,
        lastCompletedDayKey: null,
        logsByDay: {},
      );
      await fresh._save();
      return fresh;
    }

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;

      final level = (m['level'] ?? 1) as int;
      final lastKey = m['lastCompletedDayKey'] as String?;

      final logsRaw = (m['logsByDay'] as Map?) ?? {};
      final logs = <String, AuraDayLog>{};
      for (final e in logsRaw.entries) {
        final k = e.key.toString();
        logs[k] = AuraDayLog.fromJson(Map<String, dynamic>.from(e.value));
      }

      return AuraLevelManager._(
        prefs,
        level: level.clamp(1, 99),
        lastCompletedDayKey: lastKey,
        logsByDay: logs,
      );
    } catch (_) {
      final fresh = AuraLevelManager._(
        prefs,
        level: 1,
        lastCompletedDayKey: null,
        logsByDay: {},
      );
      await fresh._save();
      return fresh;
    }
  }

  int get level => _level.clamp(1, 99);
  bool get isMaxed => level >= 99;

  int get auraPoints => _auraTargetForLevel(level);

  int get nextLevel => min(level + 1, 99);
  int get nextAuraTarget => _auraTargetForLevel(nextLevel);
  int get auraGainOnNext => max(0, nextAuraTarget - auraPoints);

  double get levelProgress01 => (level / 99.0).clamp(0.0, 1.0);
  String? get lastCompletedDayKey => _lastCompletedDayKey;

  bool canStartForDay(String dayKey) {
    if (isMaxed) return false;
    return _lastCompletedDayKey != dayKey;
  }

  AuraRank get rank => AuraRank.forLevel(level);

  AuraDayLog? logForDay(String dayKey) => _logsByDay[dayKey];

  List<AuraDayLog> recentLogs({int limit = 14}) {
    final list = _logsByDay.values.toList()
      ..sort((a, b) => b.completedAtMs.compareTo(a.completedAtMs));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  int completedDaysCount() => _logsByDay.length;

  Future<void> completeLevelForDay(String dayKey, {required AuraDayLog log}) async {
    if (!canStartForDay(dayKey)) return;

    _level = (level + 1).clamp(1, 99);
    _lastCompletedDayKey = dayKey;
    _logsByDay[dayKey] = log;

    await _save();
    notifyListeners();
  }

  Future<void> resetAll() async {
    _level = 1;
    _lastCompletedDayKey = null;
    _logsByDay.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final m = <String, dynamic>{
      'level': level,
      'lastCompletedDayKey': _lastCompletedDayKey,
      'logsByDay': _logsByDay.map((k, v) => MapEntry(k, v.toJson())),
    };
    await _prefs.setString(_prefKey, jsonEncode(m));
  }

  int _auraTargetForLevel(int lvl) {
    final safe = lvl.clamp(1, 99);
    final v = (1000.0 * safe / 99.0).round();
    return v.clamp(0, 1000);
  }
}

class AuraRank {
  final String titleEn;
  final String titleTr;
  final String taglineEn;
  final String taglineTr;
  final int minLevel;
  final int maxLevel;

  const AuraRank({
    required this.titleEn,
    required this.titleTr,
    required this.taglineEn,
    required this.taglineTr,
    required this.minLevel,
    required this.maxLevel,
  });

  String title(bool isTr) => isTr ? titleTr : titleEn;
  String tagline(bool isTr) => isTr ? taglineTr : taglineEn;

  static AuraRank forLevel(int level) {
    final l = level.clamp(1, 99);

    const bands = <AuraRank>[
      AuraRank(
        titleEn: 'Rookie (1–10)',
        titleTr: 'Yeni Başlayan (1–10)',
        taglineEn: 'New spark. Build the habit.',
        taglineTr: 'Yeni kıvılcım. Alışkanlık kur.',
        minLevel: 1,
        maxLevel: 10,
      ),
      AuraRank(
        titleEn: 'Builder (11–25)',
        titleTr: 'Kurucu (11–25)',
        taglineEn: 'Consistency is power.',
        taglineTr: 'İstikrar güçtür.',
        minLevel: 11,
        maxLevel: 25,
      ),
      AuraRank(
        titleEn: 'Warrior (26–45)',
        titleTr: 'Savaşçı (26–45)',
        taglineEn: 'Discipline > mood.',
        taglineTr: 'Disiplin > mod.',
        minLevel: 26,
        maxLevel: 45,
      ),
      AuraRank(
        titleEn: 'Legend (46–70)',
        titleTr: 'Efsane (46–70)',
        taglineEn: 'Your aura is stable now.',
        taglineTr: 'Auran artık stabil.',
        minLevel: 46,
        maxLevel: 70,
      ),
      AuraRank(
        titleEn: 'Master (71–90)',
        titleTr: 'Usta (71–90)',
        taglineEn: 'You lead yourself.',
        taglineTr: 'Kendini yönetiyorsun.',
        minLevel: 71,
        maxLevel: 90,
      ),
      AuraRank(
        titleEn: 'Nirvana (91–99)',
        titleTr: 'Nirvana (91–99)',
        taglineEn: 'Calm mind. Strong body. Pure aura.',
        taglineTr: 'Sakin zihin. Güçlü beden. Saf aura.',
        minLevel: 91,
        maxLevel: 99,
      ),
    ];

    for (final b in bands) {
      if (l >= b.minLevel && l <= b.maxLevel) return b;
    }
    return bands.first;
  }
}

class AuraDayLog {
  final String dayKey;

  final int startedAtMs;
  final int completedAtMs;

  final int levelBefore;
  final int levelAfter;

  final int auraBefore;
  final int auraAfter;

  final int totalSecondsPlanned;
  final int totalSecondsSpent;

  final List<AuraStepLog> stepLogs;

  final String goalsText;
  final int goalsWordCount;

  final String? gratitude;
  final String? intention;

  AuraDayLog({
    required this.dayKey,
    required this.startedAtMs,
    required this.completedAtMs,
    required this.levelBefore,
    required this.levelAfter,
    required this.auraBefore,
    required this.auraAfter,
    required this.totalSecondsPlanned,
    required this.totalSecondsSpent,
    required this.stepLogs,
    required this.goalsText,
    required this.goalsWordCount,
    required this.gratitude,
    required this.intention,
  });

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'startedAtMs': startedAtMs,
        'completedAtMs': completedAtMs,
        'levelBefore': levelBefore,
        'levelAfter': levelAfter,
        'auraBefore': auraBefore,
        'auraAfter': auraAfter,
        'totalSecondsPlanned': totalSecondsPlanned,
        'totalSecondsSpent': totalSecondsSpent,
        'stepLogs': stepLogs.map((e) => e.toJson()).toList(),
        'goalsText': goalsText,
        'goalsWordCount': goalsWordCount,
        'gratitude': gratitude,
        'intention': intention,
      };

  static AuraDayLog fromJson(Map<String, dynamic> m) => AuraDayLog(
        dayKey: (m['dayKey'] ?? '') as String,
        startedAtMs: (m['startedAtMs'] ?? 0) as int,
        completedAtMs: (m['completedAtMs'] ?? 0) as int,
        levelBefore: (m['levelBefore'] ?? 1) as int,
        levelAfter: (m['levelAfter'] ?? 1) as int,
        auraBefore: (m['auraBefore'] ?? 0) as int,
        auraAfter: (m['auraAfter'] ?? 0) as int,
        totalSecondsPlanned: (m['totalSecondsPlanned'] ?? 0) as int,
        totalSecondsSpent: (m['totalSecondsSpent'] ?? 0) as int,
        stepLogs: ((m['stepLogs'] as List?) ?? [])
            .map((e) => AuraStepLog.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        goalsText: (m['goalsText'] ?? '') as String,
        goalsWordCount: (m['goalsWordCount'] ?? 0) as int,
        gratitude: m['gratitude'] as String?,
        intention: m['intention'] as String?,
      );
}

class AuraStepLog {
  final String id;
  final String titleEn;
  final String titleTr;
  final int plannedSeconds;
  final int spentSeconds;
  final bool confirmed;

  AuraStepLog({
    required this.id,
    required this.titleEn,
    required this.titleTr,
    required this.plannedSeconds,
    required this.spentSeconds,
    required this.confirmed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleEn': titleEn,
        'titleTr': titleTr,
        'plannedSeconds': plannedSeconds,
        'spentSeconds': spentSeconds,
        'confirmed': confirmed,
      };

  static AuraStepLog fromJson(Map<String, dynamic> m) => AuraStepLog(
        id: (m['id'] ?? '') as String,
        titleEn: (m['titleEn'] ?? '') as String,
        titleTr: (m['titleTr'] ?? '') as String,
        plannedSeconds: (m['plannedSeconds'] ?? 0) as int,
        spentSeconds: (m['spentSeconds'] ?? 0) as int,
        confirmed: (m['confirmed'] ?? false) as bool,
      );
}

class AuraLevelFlowDialog {
  static Future<void> open(
    BuildContext context, {
    required AuraLevelManager aura,
    required String dayKey,
    Future<void> Function({
      required String dayKey,
      required int auraLevelJustCompleted,
    })? onRewards,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AuraLevelDialog(
        aura: aura,
        dayKey: dayKey,
        onRewards: onRewards,
      ),
    );
  }
}

class _AuraLevelDialog extends StatefulWidget {
  final AuraLevelManager aura;
  final String dayKey;

  final Future<void> Function({
    required String dayKey,
    required int auraLevelJustCompleted,
  })? onRewards;

  const _AuraLevelDialog({
    required this.aura,
    required this.dayKey,
    required this.onRewards,
  });

  @override
  State<_AuraLevelDialog> createState() => _AuraLevelDialogState();
}

class _AuraLevelDialogState extends State<_AuraLevelDialog> {
  final _goalsCtrl = TextEditingController();
  final _gratitudeCtrl = TextEditingController();
  final _intentionCtrl = TextEditingController();

  int stepIndex = 0;

  Timer? _timer;
  bool running = false;
  int secondsLeft = 0;

  late final int startedAtMs = DateTime.now().millisecondsSinceEpoch;

  int _totalSpentSeconds = 0;
  int _stepSpentSeconds = 0;

  late List<_AuraStep> script;

  @override
  void initState() {
    super.initState();
    script = _AuraScript.buildForLevel(widget.aura.level);
    _initStep(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _goalsCtrl.dispose();
    _gratitudeCtrl.dispose();
    _intentionCtrl.dispose();
    super.dispose();
  }

  bool get isTr => Localizations.localeOf(context).languageCode == 'tr';

  int get plannedSeconds => script.fold<int>(0, (a, s) => a + (s.seconds ?? 0));

  void _initStep(int idx) {
    _timer?.cancel();
    running = false;
    _stepSpentSeconds = 0;

    final s = script[idx];

    if (s.type == _AuraStepType.timerConfirm || s.type == _AuraStepType.timerPassive) {
      secondsLeft = s.seconds ?? 0; // ✅ step başında base set (yoksa 0 -> next açık)
      if (s.type == _AuraStepType.timerConfirm) {
        s.confirmed = false;
      }
    } else {
      secondsLeft = 0;
    }
  }

  void _tickSpent() {
    _totalSpentSeconds += 1;
    _stepSpentSeconds += 1;
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    secondsLeft = seconds;
    running = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      _tickSpent();

      secondsLeft -= 1;
      if (secondsLeft <= 0) {
        secondsLeft = 0;
        _timer?.cancel();
        running = false;
        HapticFeedback.lightImpact();
      }
      setState(() {});
    });

    setState(() {});
  }

  void _stopTimer() {
    _timer?.cancel();
    running = false;
    setState(() {});
  }

  String _mmss(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  int _wordCount(String s) {
    final parts = s
        .trim()
        .split(RegExp(r'\s+'))
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList();
    return parts.length;
  }

  bool _isStepComplete(_AuraStep s) {
    switch (s.type) {
      case _AuraStepType.timerConfirm:
        return !running && secondsLeft <= 0 && s.confirmed;
      case _AuraStepType.timerPassive:
        return !running && secondsLeft <= 0;
      case _AuraStepType.textMinWords:
        return _wordCount(_goalsCtrl.text) >= (s.minWords ?? 20);
      case _AuraStepType.gratitudeIntention:
        final g = _wordCount(_gratitudeCtrl.text);
        final i = _wordCount(_intentionCtrl.text);
        return (g >= 3) || (i >= 3);
    }
  }

  Future<void> _next() async {
    if (running) return;

    _totalSpentSeconds += 1;
    _stepSpentSeconds += 1;

    final cur = script[stepIndex];
    _finalizeStep(cur);

    if (stepIndex < script.length - 1) {
      setState(() {
        stepIndex += 1;
        _initStep(stepIndex);
      });
      return;
    }

    final aura = widget.aura;
    final beforeLevel = aura.level;
    final beforeAura = aura.auraPoints;
    final afterLevel = aura.nextLevel;
    final afterAura = aura.nextAuraTarget;
    final completedAtMs = DateTime.now().millisecondsSinceEpoch;

    final goalsText = _goalsCtrl.text.trim();
    final wc = _wordCount(goalsText);

    final totalSpent = max(plannedSeconds, _totalSpentSeconds);

    final log = AuraDayLog(
      dayKey: widget.dayKey,
      startedAtMs: startedAtMs,
      completedAtMs: completedAtMs,
      levelBefore: beforeLevel,
      levelAfter: afterLevel,
      auraBefore: beforeAura,
      auraAfter: afterAura,
      totalSecondsPlanned: plannedSeconds,
      totalSecondsSpent: totalSpent,
      stepLogs: _stepLogs,
      goalsText: goalsText,
      goalsWordCount: wc,
      gratitude: _gratitudeCtrl.text.trim().isEmpty ? null : _gratitudeCtrl.text.trim(),
      intention: _intentionCtrl.text.trim().isEmpty ? null : _intentionCtrl.text.trim(),
    );

    if (widget.onRewards != null) {
      await widget.onRewards!(dayKey: widget.dayKey, auraLevelJustCompleted: beforeLevel);
    }

    await aura.completeLevelForDay(widget.dayKey, log: log);

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isTr
            ? 'LEVEL UP! L${beforeLevel + 1} • Aura ${aura.auraPoints}/1000'
            : 'LEVEL UP! L${beforeLevel + 1} • Aura ${aura.auraPoints}/1000'),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  void _exit() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  final List<AuraStepLog> _stepLogs = [];

  void _finalizeStep(_AuraStep s) {
    if (_stepLogs.any((x) => x.id == s.id)) return;

    _stepLogs.add(
      AuraStepLog(
        id: s.id,
        titleEn: s.titleEn,
        titleTr: s.titleTr,
        plannedSeconds: s.seconds ?? 0,
        spentSeconds: max(1, _stepSpentSeconds),
        confirmed: s.type == _AuraStepType.timerConfirm ? s.confirmed : true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    final aura = widget.aura;

    final canStart = aura.canStartForDay(widget.dayKey);
    if (!canStart || aura.isMaxed) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: p),
            const SizedBox(width: 10),
            Expanded(child: Text(isTr ? 'Aura Level' : 'Aura Level')),
          ],
        ),
        content: Text(
          aura.isMaxed
              ? (isTr ? 'Aura MAX (1000). Level 99.' : 'Aura MAX (1000). Level 99.')
              : (isTr ? 'Bugün zaten level yaptın. Yarın tekrar.' : 'You already leveled up today. Come back tomorrow.'),
          style: TextStyle(color: Colors.white.withOpacity(0.80), fontWeight: FontWeight.w700),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      );
    }

    final cur = script[stepIndex];
    final progress01 = ((stepIndex + 1) / script.length).clamp(0.0, 1.0);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: p),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isTr ? 'AURA LEVEL • L${aura.level} → L${aura.nextLevel}' : 'AURA LEVEL • L${aura.level} → L${aura.nextLevel}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress01,
                minHeight: 10,
                backgroundColor: Colors.white.withOpacity(0.10),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${aura.rank.title(isTr)} • +${aura.auraGainOnNext} • ${isTr ? 'Hedef' : 'Target'} ${aura.nextAuraTarget}/1000',
                    style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StepCard(
              title: isTr ? cur.titleTr : cur.titleEn,
              subtitle: isTr ? cur.subtitleTr : cur.subtitleEn,
              child: _buildStepBody(context, cur),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _exit, child: Text(isTr ? 'Çık' : 'Exit')),
        FilledButton(
          onPressed: _isStepComplete(cur) ? _next : null,
          child: Text(stepIndex == script.length - 1 ? (isTr ? 'Tamamla' : 'Complete') : (isTr ? 'İleri' : 'Next')),
        ),
      ],
    );
  }

  Widget _buildStepBody(BuildContext context, _AuraStep s) {
    final p = Theme.of(context).colorScheme.primary;

    if (s.type == _AuraStepType.timerConfirm) {
      final base = s.seconds ?? 40;
      final showTime = _mmss(running ? secondsLeft : secondsLeft);
      final doneReady = !running && secondsLeft <= 0;

      return Column(
        children: [
          Center(child: Text(showTime, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (running) {
                      _stopTimer();
                    } else {
                      s.confirmed = false;
                      _startTimer(base);
                    }
                  },
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(isTr ? (running ? 'Duraklat' : 'Başlat') : (running ? 'Pause' : 'Start')),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: doneReady
                    ? () {
                        HapticFeedback.mediumImpact();
                        s.confirmed = true;
                        setState(() {});
                      }
                    : null,
                child: Text(isTr ? (s.confirmButtonTr ?? 'Yaptım') : (s.confirmButtonEn ?? 'I did')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!doneReady)
            Text(
              isTr ? (s.hintTr ?? '') : (s.hintEn ?? ''),
              style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w700),
            ),
          if (doneReady && !s.confirmed)
            Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.white.withOpacity(0.70), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTr
                        ? 'Timer bitti. Şimdi "${s.confirmButtonTr ?? 'Yaptım'}" de.'
                        : 'Timer done. Now press "${s.confirmButtonEn ?? 'I did'}".',
                    style: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          if (s.confirmed)
            Row(
              children: [
                Icon(Icons.check_circle, color: p),
                const SizedBox(width: 8),
                Text(isTr ? 'Onaylandı' : 'Confirmed', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
        ],
      );
    }

    if (s.type == _AuraStepType.timerPassive) {
      final base = s.seconds ?? 60;
      final showTime = _mmss(running ? secondsLeft : secondsLeft);

      return Column(
        children: [
          Center(child: Text(showTime, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (running) {
                      _stopTimer();
                    } else {
                      _startTimer(base);
                    }
                  },
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(isTr ? (running ? 'Duraklat' : 'Başlat') : (running ? 'Pause' : 'Start')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTr ? (s.hintTr ?? '') : (s.hintEn ?? ''),
            style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    if (s.type == _AuraStepType.textMinWords) {
      final minWords = s.minWords ?? 20;
      final wc = _wordCount(_goalsCtrl.text);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Min $minWords kelime • Şu an: $wc' : 'Min $minWords words • Now: $wc',
            style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _goalsCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: isTr ? (s.hintTr ?? 'Buraya yaz…') : (s.hintEn ?? 'Write here…'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          if (wc < minWords)
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white.withOpacity(0.70), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTr ? '20 kelime altı olmaz. Biraz daha yaz.' : 'Not enough. Write a bit more.',
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          if (wc >= minWords)
            Row(
              children: [
                Icon(Icons.check_circle, color: p),
                const SizedBox(width: 8),
                Text(isTr ? 'Güzel. Devam edebilirsin.' : 'Good. You can continue.',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
        ],
      );
    }

    final gWc = _wordCount(_gratitudeCtrl.text);
    final iWc = _wordCount(_intentionCtrl.text);
    final ok = (gWc >= 3) || (iWc >= 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTr ? 'En az birine 3+ kelime yaz.' : 'Write at least one (3+ words).',
          style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _gratitudeCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: isTr ? 'Şükür (örn: Bugün şuna minnettarım...)' : 'Gratitude (e.g., I am grateful for …)',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _intentionCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: isTr ? 'Niyet (örn: Bugün şunu yapacağım...)' : 'Intention (e.g., Today I will …)',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.lock_clock,
                color: ok ? p : Colors.white.withOpacity(0.70), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok
                    ? (isTr ? 'Süper. Tamamlayabilirsin.' : 'Perfect. Ready to complete.')
                    : (isTr ? 'En az birine 3 kelime yaz.' : 'Write 3+ words in one field.'),
                style: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _AuraStepType { timerConfirm, timerPassive, textMinWords, gratitudeIntention }

class _AuraStep {
  final String id;
  final _AuraStepType type;

  final String titleEn;
  final String titleTr;

  final String subtitleEn;
  final String subtitleTr;

  final int? seconds;

  final String? hintEn;
  final String? hintTr;

  final int? minWords;

  bool confirmed;
  final String? confirmButtonEn;
  final String? confirmButtonTr;

  _AuraStep.timerConfirm({
    required this.id,
    required this.titleEn,
    required this.titleTr,
    required this.subtitleEn,
    required this.subtitleTr,
    required this.seconds,
    this.hintEn,
    this.hintTr,
    this.confirmButtonEn,
    this.confirmButtonTr,
  })  : type = _AuraStepType.timerConfirm,
        minWords = null,
        confirmed = false;

  _AuraStep.timerPassive({
    required this.id,
    required this.titleEn,
    required this.titleTr,
    required this.subtitleEn,
    required this.subtitleTr,
    required this.seconds,
    this.hintEn,
    this.hintTr,
  })  : type = _AuraStepType.timerPassive,
        minWords = null,
        confirmed = false,
        confirmButtonEn = null,
        confirmButtonTr = null;

  _AuraStep.textMinWords({
    required this.id,
    required this.titleEn,
    required this.titleTr,
    required this.subtitleEn,
    required this.subtitleTr,
    required this.minWords,
    this.hintEn,
    this.hintTr,
  })  : type = _AuraStepType.textMinWords,
        seconds = null,
        confirmed = true,
        confirmButtonEn = null,
        confirmButtonTr = null;

  _AuraStep.gratitudeIntention({
    required this.id,
    required this.titleEn,
    required this.titleTr,
    required this.subtitleEn,
    required this.subtitleTr,
  })  : type = _AuraStepType.gratitudeIntention,
        seconds = null,
        hintEn = null,
        hintTr = null,
        minWords = null,
        confirmed = true,
        confirmButtonEn = null,
        confirmButtonTr = null;
}

class _AuraScript {
  static List<_AuraStep> buildForLevel(int level) {
    final l = level.clamp(1, 99);

    final extra = (l >= 50) ? 10 : 0;
    final focusSeconds = 75 + extra;

    return [
      _AuraStep.timerConfirm(
        id: 'pushups',
        titleEn: '1) 10 Push-ups',
        titleTr: '1) 10 Şınav',
        subtitleEn: 'Start. 40 seconds. Finish strong.',
        subtitleTr: 'Başla. 40 saniye. Güçlü bitir.',
        seconds: 40,
        hintEn: 'Only one rule: don’t stop. Even slow reps count.',
        hintTr: 'Tek kural: durma. Yavaş tekrar da sayılır.',
        confirmButtonEn: 'I did 10',
        confirmButtonTr: '10 yaptım',
      ),
      _AuraStep.timerPassive(
        id: 'breath',
        titleEn: '2) Breath Reset',
        titleTr: '2) Nefes Reset',
        subtitleEn: 'Slow inhale… slow exhale…',
        subtitleTr: 'Yavaş al… yavaş ver…',
        seconds: 60,
        hintEn: 'If your mind drifts, say: “Return.” Then return to breath.',
        hintTr: 'Zihin kayarsa “geri dön” de ve nefese dön.',
      ),
      _AuraStep.textMinWords(
        id: 'write',
        titleEn: '3) Write your goals + skills',
        titleTr: '3) Hedef + yetenek yaz',
        subtitleEn: 'Minimum 20 words. Describe your plan and what you’re building.',
        subtitleTr: 'Minimum 20 kelime. Planını ve neyi inşa ettiğini yaz.',
        minWords: 20,
        hintEn: 'Example: “I’m building discipline. Today I will… My next step is…”',
        hintTr: 'Örnek: “Disiplin kuruyorum. Bugün… Sonraki adımım…”',
      ),
      _AuraStep.timerPassive(
        id: 'close_eyes',
        titleEn: '4) Close your eyes',
        titleTr: '4) Gözlerini kapat',
        subtitleEn: 'Close your eyes and just listen to your thoughts.',
        subtitleTr: 'Gözlerini kapat ve sadece düşüncelerini dinle.',
        seconds: focusSeconds,
        hintEn: 'No judgement. Just notice. Let it pass.',
        hintTr: 'Yargılama. Sadece fark et. Geçip gitsin.',
      ),
      _AuraStep.gratitudeIntention(
        id: 'gratitude_intention',
        titleEn: '5) Gratitude + Intention',
        titleTr: '5) Şükür + Niyet',
        subtitleEn: 'One small gratitude + one clear intention.',
        subtitleTr: 'Küçük bir şükür + net bir niyet.',
      ),
    ];
  }
}
