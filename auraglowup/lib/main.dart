import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
import 'auralevelmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = await AppController.bootstrap();
  final aura = await AuraLevelManager.bootstrap();
  final coach = await AuraCoachManager.bootstrap();

  runApp(AuraGlowUpApp(controller: controller, aura: aura, coach: coach));
}

class AuraGlowUpApp extends StatelessWidget {
  final AppController controller;
  final AuraLevelManager aura;
  final AuraCoachManager coach;

  const AuraGlowUpApp({
    super.key,
    required this.controller,
    required this.aura,
    required this.coach,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([controller, aura, coach]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        return MaterialApp(
          title: 'Aura GlowUp',
          debugShowCheckedModeBanner: false,
          theme: AuraTheme.theme(),
          locale: controller.state.localeCode == null ? null : Locale(controller.state.localeCode!),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: controller.state.localeCode == null
              ? LanguagePickScreen(onPick: (code) => controller.setLocale(code))
              : AuraShell(controller: controller, aura: aura, coach: coach),
        );
      },
    );
  }
}

class AuraShell extends StatefulWidget {
  final AppController controller;
  final AuraLevelManager aura;
  final AuraCoachManager coach;

  const AuraShell({super.key, required this.controller, required this.aura, required this.coach});

  @override
  State<AuraShell> createState() => _AuraShellState();
}

class _AuraShellState extends State<AuraShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final labels = [
      S.t(context, 'today'),
      S.t(context, 'areas'),
      S.t(context, 'goals'),
      S.t(context, 'profile'),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const FancyBackground(animated: true),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: S.t(context, 'appName'),
                  onSettings: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen(controller: widget.controller)),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: index,
                    children: [
                      TodayDashboardTab(controller: widget.controller, aura: widget.aura, coach: widget.coach),
                      AreasTab(coach: widget.coach),
                      GoalsTab(coach: widget.coach),
                      ProfileTab(aura: widget.aura, coach: widget.coach),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: NavigationBar(
          backgroundColor: Colors.black.withOpacity(0.30),
          elevation: 0,
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), label: labels[0]),
            NavigationDestination(icon: const Icon(Icons.grid_view_rounded), label: labels[1]),
            NavigationDestination(icon: const Icon(Icons.track_changes_outlined), label: labels[2]),
            NavigationDestination(icon: const Icon(Icons.person_outline), label: labels[3]),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// TODAY (Dashboard)
/// ------------------------------------------------------------
class TodayDashboardTab extends StatefulWidget {
  final AppController controller; // sadece locale/ayarlar için duruyor
  final AuraLevelManager aura;
  final AuraCoachManager coach;

  const TodayDashboardTab({super.key, required this.controller, required this.aura, required this.coach});

  @override
  State<TodayDashboardTab> createState() => _TodayDashboardTabState();
}

class _TodayDashboardTabState extends State<TodayDashboardTab> {
  late DateTime selectedDay;

  @override
  void initState() {
    super.initState();
    selectedDay = _onlyDate(DateTime.now());
  }

  void _setDay(DateTime d) => setState(() => selectedDay = _onlyDate(d));

  @override
  Widget build(BuildContext context) {
    final dayKey = _dayKey(selectedDay);
    final todayKey = _dayKey(_onlyDate(DateTime.now()));
    final isToday = dayKey == todayKey;

    final score = widget.coach.dayScore01(dayKey);
    final score100 = (score * 100).round();
    final completionPct = widget.coach.dayCompletion01(dayKey);
    final completion100 = (completionPct * 100).round();

    final auraMgr = widget.aura;
    final canStartAura = isToday && auraMgr.canStartForDay(dayKey) && !auraMgr.isMaxed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
      children: [
        // Header summary
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${S.t(context, 'today')} • $completion100%  •  ${S.t(context, 'auraScore')}: $score100/100',
                  style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: S.t(context, 'goToday'),
                onPressed: () => _setDay(_onlyDate(DateTime.now())),
                icon: const Icon(Icons.today),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Date quick nav (lightweight)
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _setDay(selectedDay.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _prettyDate(context, selectedDay),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _setDay(selectedDay.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Aura Level card (senin premium flow)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 8),
                  Text(S.t(context, 'auraLevel'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(
                    auraMgr.isMaxed ? S.t(context, 'auraMaxed') : 'L${auraMgr.level}',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${auraMgr.rank.title(Localizations.localeOf(context).languageCode == 'tr')} • ${S.t(context, 'auraPoints')}: ${auraMgr.auraPoints}/1000',
                style: TextStyle(color: Colors.white.withOpacity(0.82), fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: auraMgr.levelProgress01,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.10),
                ),
              ),
              const SizedBox(height: 12),
              _GlowButton(
                label: auraMgr.isMaxed
                    ? S.t(context, 'auraMaxed')
                    : (canStartAura ? S.t(context, 'startAuraRun') : S.t(context, 'auraRunDone')),
                icon: Icons.play_arrow_rounded,
                onPressed: canStartAura
                    ? () async {
                        HapticFeedback.mediumImpact();
                        await AuraLevelFlowDialog.open(
                          context,
                          aura: auraMgr,
                          dayKey: dayKey,
                          onRewards: ({required String dayKey, required int auraLevelJustCompleted}) async {
                            // Ödül hissi için küçük bonus: Spiritual alanına + küçük puan
                            await widget.coach.giveTinyBonus(dayKey);
                          },
                        );
                      }
                    : null,
              ),
              if (!isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'tr'
                        ? 'Aura Run sadece bugün için çalışır.'
                        : 'Aura Run works only for today.',
                    style: TextStyle(color: Colors.white.withOpacity(0.60), fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text(S.t(context, 'focusAreas'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),

        // Areas quick cards
        for (final area in AuraArea.values) ...[
          _AreaQuickCard(
            area: area,
            dayKey: dayKey,
            coach: widget.coach,
            isToday: isToday,
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AreaDetailScreen(area: area, coach: widget.coach, dayKey: dayKey)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AreaQuickCard extends StatelessWidget {
  final AuraArea area;
  final String dayKey;
  final AuraCoachManager coach;
  final bool isToday;
  final VoidCallback onOpen;

  const _AreaQuickCard({
    required this.area,
    required this.dayKey,
    required this.coach,
    required this.isToday,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final areaScore = coach.areaScore01(dayKey, area);
    final score100 = (areaScore * 100).round();
    final done = coach.isAreaSessionDone(dayKey, area);
    final canStart = isToday && coach.canStartAreaSession(dayKey, area);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AreaIcon(area: area),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  area.title(Localizations.localeOf(context).languageCode == 'tr'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              _Pill(text: '$score100/100', icon: Icons.bolt, glow: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            area.subtitle(Localizations.localeOf(context).languageCode == 'tr'),
            style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: areaScore,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GlowButton(
                  label: done ? S.t(context, 'doneToday') : (canStart ? S.t(context, 'startSession') : S.t(context, 'notToday')),
                  icon: Icons.play_arrow_rounded,
                  onPressed: canStart
                      ? () async {
                          HapticFeedback.mediumImpact();
                          await AreaSessionFlowDialog.open(context, coach: coach, area: area, dayKey: dayKey);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: S.t(context, 'open'),
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_ios_rounded),
              ),
            ],
          ),
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                Localizations.localeOf(context).languageCode == 'tr'
                    ? 'Session sadece “Bugün” tamamlanabilir.'
                    : 'Session can be completed only for “Today”.',
                style: TextStyle(color: Colors.white.withOpacity(0.58), fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// AREAS TAB (Grid)
/// ------------------------------------------------------------
class AreasTab extends StatelessWidget {
  final AuraCoachManager coach;
  const AreasTab({super.key, required this.coach});

  @override
  Widget build(BuildContext context) {
    final todayKey = _dayKey(_onlyDate(DateTime.now()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
      children: [
        Text(S.t(context, 'areas'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        GlassCard(
          child: Text(
            Localizations.localeOf(context).languageCode == 'tr'
                ? 'Sadece seçtiğin alana odaklan. Her alanın: Session + Checklist + AI Promptları var.'
                : 'Focus on only what you want. Each area has: Session + Checklist + AI Prompts.',
            style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final crossAxisCount = w > 520 ? 2 : 1;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: crossAxisCount == 2 ? 2.0 : 2.4,
              children: [
                for (final area in AuraArea.values)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AreaDetailScreen(area: area, coach: coach, dayKey: todayKey)),
                    ),
                    child: GlassCard(
                      child: Row(
                        children: [
                          _AreaIcon(area: area, big: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  area.title(Localizations.localeOf(context).languageCode == 'tr'),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  area.subtitle(Localizations.localeOf(context).languageCode == 'tr'),
                                  style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// AREA DETAIL
/// ------------------------------------------------------------
class AreaDetailScreen extends StatefulWidget {
  final AuraArea area;
  final AuraCoachManager coach;
  final String dayKey;

  const AreaDetailScreen({super.key, required this.area, required this.coach, required this.dayKey});

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final area = widget.area;
    final coach = widget.coach;
    final dayKey = widget.dayKey;

    final tasks = coach.tasksForArea(area);
    final done = coach.isAreaSessionDone(dayKey, area);
    final canStart = coach.canStartAreaSession(dayKey, area) && dayKey == _dayKey(_onlyDate(DateTime.now()));
    final areaScore = coach.areaScore01(dayKey, area);
    final score100 = (areaScore * 100).round();

    noteCtrl.text = coach.noteForDay(dayKey, area) ?? '';

    return Scaffold(
      body: Stack(
        children: [
          const FancyBackground(animated: true),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new)),
                    const SizedBox(width: 6),
                    Text(area.title(isTr), style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),

                const SizedBox(height: 10),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _AreaIcon(area: area),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              area.subtitle(isTr),
                              style: TextStyle(color: Colors.white.withOpacity(0.80), fontWeight: FontWeight.w800),
                            ),
                          ),
                          _Pill(text: '$score100/100', icon: Icons.bolt, glow: true),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: areaScore,
                          minHeight: 10,
                          backgroundColor: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlowButton(
                        label: done ? S.t(context, 'doneToday') : (canStart ? S.t(context, 'startSession') : S.t(context, 'notToday')),
                        icon: Icons.play_arrow_rounded,
                        onPressed: canStart
                            ? () async {
                                HapticFeedback.mediumImpact();
                                await AreaSessionFlowDialog.open(context, coach: coach, area: area, dayKey: dayKey);
                                setState(() {});
                              }
                            : null,
                      ),
                      if (!canStart && !done)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            isTr ? 'Session sadece “Bugün” çalışır.' : 'Session works only for “Today”.',
                            style: TextStyle(color: Colors.white.withOpacity(0.60), fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Text(S.t(context, 'aiPrompts'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),

                for (final p in area.prompts(isTr)) ...[
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(
                          p.body,
                          style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700, height: 1.25),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: p.body));
                                  HapticFeedback.selectionClick();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(isTr ? 'Kopyalandı ✅' : 'Copied ✅')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: Text(isTr ? 'Kopyala' : 'Copy'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 6),
                Text(S.t(context, 'checklist'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final t in tasks)
                        _ChecklistRow(
                          title: t.title,
                          checked: coach.isTaskChecked(dayKey, area, t.id),
                          onChanged: (v) async {
                            await coach.setTaskChecked(dayKey, area, t.id, v);
                            setState(() {});
                          },
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addTaskSheet(context, area, coach, onDone: () => setState(() {})),
                              icon: const Icon(Icons.add),
                              label: Text(S.t(context, 'addTask')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Text(S.t(context, 'notes'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTr ? 'Bugün ne hissettin? 2–3 cümle yeter.' : 'How did you feel today? 2–3 lines is enough.',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: isTr ? 'Not yaz…' : 'Write a note…',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GlowButton(
                        label: S.t(context, 'save'),
                        icon: Icons.save_rounded,
                        onPressed: () async {
                          await coach.setNoteForDay(dayKey, area, noteCtrl.text.trim());
                          HapticFeedback.selectionClick();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isTr ? 'Kaydedildi ✅' : 'Saved ✅')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                if (coach.sessionLogForDay(dayKey, area) != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.t(context, 'sessionLog'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(
                          coach.sessionLogForDay(dayKey, area) ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTaskSheet(BuildContext context, AuraArea area, AuraCoachManager coach, {required VoidCallback onDone}) async {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final ctrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _Sheet(
            title: isTr ? 'Görev ekle' : 'Add task',
            child: Column(
              children: [
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: isTr ? 'Örn: 10 dk yürüyüş' : 'Ex: 10 min walk',
                  ),
                ),
                const SizedBox(height: 12),
                _GlowButton(
                  label: isTr ? 'Ekle' : 'Add',
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    await coach.addTask(area, text);
                    if (context.mounted) Navigator.pop(ctx);
                    onDone();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    ctrl.dispose();
  }
}

class _ChecklistRow extends StatelessWidget {
  final String title;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _ChecklistRow({required this.title, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: checked,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: checked ? Colors.white.withOpacity(0.75) : Colors.white.withOpacity(0.92),
              decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
              decorationColor: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// GOALS TAB (Full)
/// ------------------------------------------------------------
class GoalsTab extends StatefulWidget {
  final AuraCoachManager coach;
  const GoalsTab({super.key, required this.coach});

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  AuraArea? filterArea;

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final dayKey = _dayKey(_onlyDate(DateTime.now()));

    final goals = widget.coach.goals.where((g) => filterArea == null ? true : g.area == filterArea).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
          children: [
            Row(
              children: [
                Text(S.t(context, 'goals'), style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                DropdownButton<AuraArea?>(
                  value: filterArea,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isTr ? 'Hepsi' : 'All')),
                    for (final a in AuraArea.values)
                      DropdownMenuItem(value: a, child: Text(a.title(isTr))),
                  ],
                  onChanged: (v) => setState(() => filterArea = v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (goals.isEmpty)
              GlassCard(
                child: Text(
                  isTr
                      ? 'Hedef ekle: Habit (günlük işaretle) veya Progress (sayı artır).'
                      : 'Add a goal: Habit (daily check) or Progress (increase a number).',
                  style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700),
                ),
              ),

            for (final g in goals) ...[
              const SizedBox(height: 12),
              _GoalCard(
                goal: g,
                dayKey: dayKey,
                coach: widget.coach,
                onChanged: () => setState(() {}),
              ),
            ],
          ],
        ),

        Positioned(
          right: 18,
          bottom: 92,
          child: FloatingActionButton.extended(
            onPressed: () => _openGoalEditor(context, widget.coach, onDone: () => setState(() {})),
            icon: const Icon(Icons.add),
            label: Text(isTr ? 'Hedef ekle' : 'Add goal'),
          ),
        ),
      ],
    );
  }

  Future<void> _openGoalEditor(BuildContext context, AuraCoachManager coach, {required VoidCallback onDone, AuraGoal? edit}) async {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    final titleCtrl = TextEditingController(text: edit?.title ?? '');
    AuraArea area = edit?.area ?? AuraArea.mental;
    GoalType type = edit?.type ?? GoalType.habit;
    final targetCtrl = TextEditingController(text: edit?.target?.toString() ?? '');
    final unitCtrl = TextEditingController(text: edit?.unit ?? (isTr ? 'dk' : 'min'));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _Sheet(
            title: edit == null ? (isTr ? 'Yeni hedef' : 'New goal') : (isTr ? 'Hedefi düzenle' : 'Edit goal'),
            child: Column(
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(hintText: isTr ? 'Hedef başlığı' : 'Goal title'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AuraArea>(
                        value: area,
                        items: [
                          for (final a in AuraArea.values)
                            DropdownMenuItem(value: a, child: Text(a.title(isTr))),
                        ],
                        onChanged: (v) => area = v ?? area,
                        decoration: InputDecoration(labelText: isTr ? 'Alan' : 'Area'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<GoalType>(
                        value: type,
                        items: [
                          DropdownMenuItem(value: GoalType.habit, child: Text(isTr ? 'Habit' : 'Habit')),
                          DropdownMenuItem(value: GoalType.progress, child: Text(isTr ? 'Progress' : 'Progress')),
                        ],
                        onChanged: (v) => type = v ?? type,
                        decoration: InputDecoration(labelText: isTr ? 'Tip' : 'Type'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isTr ? 'Hedef (opsiyonel)' : 'Target (optional)',
                          hintText: isTr ? 'Örn: 20' : 'Ex: 20',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: InputDecoration(
                          labelText: isTr ? 'Birim' : 'Unit',
                          hintText: isTr ? 'dk / adet / sayfa' : 'min / reps / pages',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _GlowButton(
                        label: edit == null ? (isTr ? 'Ekle' : 'Add') : (isTr ? 'Kaydet' : 'Save'),
                        icon: Icons.check_rounded,
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;

                          final target = int.tryParse(targetCtrl.text.trim());
                          final unit = unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim();

                          if (edit == null) {
                            await coach.addGoal(
                              title: title,
                              area: area,
                              type: type,
                              target: target,
                              unit: unit,
                            );
                          } else {
                            await coach.updateGoal(
                              edit.id,
                              title: title,
                              area: area,
                              type: type,
                              target: target,
                              unit: unit,
                            );
                          }

                          if (context.mounted) Navigator.pop(ctx);
                          onDone();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    titleCtrl.dispose();
    targetCtrl.dispose();
    unitCtrl.dispose();
  }
}

class _GoalCard extends StatelessWidget {
  final AuraGoal goal;
  final String dayKey;
  final AuraCoachManager coach;
  final VoidCallback onChanged;

  const _GoalCard({required this.goal, required this.dayKey, required this.coach, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    final done = coach.isGoalDoneForDay(goal.id, dayKey);
    final progress = coach.goalProgressForDay(goal.id, dayKey);
    final target = goal.target;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AreaIcon(area: goal.area),
              const SizedBox(width: 10),
              Expanded(
                child: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              IconButton(
                tooltip: isTr ? 'Sil' : 'Delete',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(isTr ? 'Silinsin mi?' : 'Delete?'),
                      content: Text(isTr ? 'Hedef silinecek.' : 'This goal will be deleted.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.t(context, 'cancel'))),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(S.t(context, 'delete'))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await coach.deleteGoal(goal.id);
                    onChanged();
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Pill(text: goal.type == GoalType.habit ? 'Habit' : 'Progress', icon: Icons.flag_outlined),
              const SizedBox(width: 8),
              if (goal.unit != null) _Pill(text: goal.unit!, icon: Icons.straighten_rounded),
              const Spacer(),
              _Pill(
                text: coach.goalStreakText(goal.id, isTr: isTr),
                icon: Icons.local_fire_department_rounded,
                glow: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (goal.type == GoalType.habit)
            Row(
              children: [
                Expanded(
                  child: _GlowButton(
                    label: done ? (isTr ? 'Bugün tamam' : 'Done today') : (isTr ? 'Bugün yapıldı' : 'Mark done'),
                    icon: done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                    onPressed: () async {
                      await coach.toggleHabit(goal.id, dayKey);
                      HapticFeedback.selectionClick();
                      onChanged();
                    },
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target == null
                      ? (isTr ? 'Bugün: $progress' : 'Today: $progress')
                      : (isTr ? 'Bugün: $progress / $target' : 'Today: $progress / $target'),
                  style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (target != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (progress / target).clamp(0, 1).toDouble(),
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.10),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await coach.addProgress(goal.id, dayKey, 1);
                          HapticFeedback.selectionClick();
                          onChanged();
                        },
                        icon: const Icon(Icons.add),
                        label: Text(isTr ? '+1' : '+1'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await coach.addProgress(goal.id, dayKey, 5);
                          HapticFeedback.selectionClick();
                          onChanged();
                        },
                        icon: const Icon(Icons.add),
                        label: Text(isTr ? '+5' : '+5'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await coach.addProgress(goal.id, dayKey, -1);
                          HapticFeedback.selectionClick();
                          onChanged();
                        },
                        icon: const Icon(Icons.remove),
                        label: Text(isTr ? '-1' : '-1'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// PROFILE TAB (score + streak)
/// ------------------------------------------------------------
class ProfileTab extends StatelessWidget {
  final AuraLevelManager aura;
  final AuraCoachManager coach;

  const ProfileTab({super.key, required this.aura, required this.coach});

  @override
  Widget build(BuildContext context) {
    final today = _onlyDate(DateTime.now());
    final todayKey = _dayKey(today);

    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    final streak = coach.currentStreak(todayKey);
    final best = coach.bestStreak();

    final avg7 = coach.last7DaysAvg01(todayKey);
    final avg7Text = (avg7 * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
      children: [
        Text(S.t(context, 'profileTitle'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 8),
                  Text(S.t(context, 'auraLevel'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(
                    aura.isMaxed ? S.t(context, 'auraMaxed') : 'L${aura.level}',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${S.t(context, 'rank')}: ${aura.rank.title(isTr)}',
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${S.t(context, 'auraPoints')}: ${aura.auraPoints}/1000',
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: aura.levelProgress01,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.10),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(S.t(context, 'resetAura')),
                      content: Text(isTr ? 'Aura Level ilerlemen sıfırlanacak.' : 'Your Aura Level progress will be reset.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.t(context, 'cancel'))),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(S.t(context, 'delete'))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await aura.resetAll();
                  }
                },
                icon: const Icon(Icons.restart_alt),
                label: Text(S.t(context, 'resetAura')),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        GlassCard(
          child: Row(
            children: [
              Expanded(child: Text('Streak: $streak', style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(child: Text('Best: $best', style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(child: Text('Aura avg: $avg7Text/100', style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
        ),

        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isTr ? 'Bugün skorun' : 'Your score today', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: coach.dayScore01(todayKey),
                  minHeight: 12,
                  backgroundColor: Colors.white.withOpacity(0.10),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${S.t(context, 'auraScore')}: ${(coach.dayScore01(todayKey) * 100).round()}/100',
                style: TextStyle(color: Colors.white.withOpacity(0.80), fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// SESSION FLOW (Per area, daily)
/// ------------------------------------------------------------
class AreaSessionFlowDialog extends StatefulWidget {
  final AuraCoachManager coach;
  final AuraArea area;
  final String dayKey;

  const AreaSessionFlowDialog({super.key, required this.coach, required this.area, required this.dayKey});

  static Future<void> open(BuildContext context, {required AuraCoachManager coach, required AuraArea area, required String dayKey}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AreaSessionFlowDialog(coach: coach, area: area, dayKey: dayKey),
    );
  }

  @override
  State<AreaSessionFlowDialog> createState() => _AreaSessionFlowDialogState();
}

class _AreaSessionFlowDialogState extends State<AreaSessionFlowDialog> {
  int step = 0;
  int secondsLeft = 180; // 3 min default
  Timer? timer;

  final journalCtrl = TextEditingController();
  bool running = false;

  @override
  void dispose() {
    timer?.cancel();
    journalCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 0) {
        t.cancel();
        setState(() {
          running = false;
          step = 1;
        });
        HapticFeedback.mediumImpact();
      } else {
        setState(() => secondsLeft -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final area = widget.area;

    final title = area.title(isTr);
    final prompt = area.sessionPrompt(isTr);

    return AlertDialog(
      title: Row(
        children: [
          _AreaIcon(area: area),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: step == 0
              ? _StepTimer(
                  key: const ValueKey('timer'),
                  secondsLeft: secondsLeft,
                  running: running,
                  prompt: prompt,
                  onPick: (sec) => setState(() => secondsLeft = sec),
                  onStart: _startTimer,
                )
              : step == 1
                  ? _StepJournal(
                      key: const ValueKey('journal'),
                      isTr: isTr,
                      controller: journalCtrl,
                      area: area,
                      onNext: () => setState(() => step = 2),
                    )
                  : _StepCopyPrompt(
                      key: const ValueKey('copy'),
                      isTr: isTr,
                      area: area,
                      onFinish: () async {
                        final sec = secondsLeft; // kalan değil; log için kullanacağız (yaklaşık)
                        final log = '${isTr ? "Session tamamlandı" : "Session completed"} • ${DateTime.now().toIso8601String()}';
                        final journal = journalCtrl.text.trim();

                        await widget.coach.completeAreaSession(widget.dayKey, area, durationSec: max(60, sec), journal: journal, log: log);

                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
        ),
      ),
      actions: [
        if (step > 0)
          TextButton(
            onPressed: () => setState(() => step -= 1),
            child: Text(isTr ? 'Geri' : 'Back'),
          ),
        TextButton(
          onPressed: () {
            timer?.cancel();
            Navigator.pop(context);
          },
          child: Text(isTr ? 'Kapat' : 'Close'),
        ),
      ],
    );
  }
}

class _StepTimer extends StatelessWidget {
  final int secondsLeft;
  final bool running;
  final String prompt;
  final void Function(int sec) onPick;
  final VoidCallback onStart;

  const _StepTimer({
    super.key,
    required this.secondsLeft,
    required this.running,
    required this.prompt,
    required this.onPick,
    required this.onStart,
  });

  String _mmss(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _mmss(secondsLeft),
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChipButton(label: '3m', onTap: () => onPick(180)),
            _ChipButton(label: '4m', onTap: () => onPick(240)),
            _ChipButton(label: '5m', onTap: () => onPick(300)),
          ],
        ),
        const SizedBox(height: 12),
        _GlowButton(
          label: running ? (isTr ? 'Çalışıyor…' : 'Running…') : (isTr ? 'Başlat' : 'Start'),
          icon: Icons.play_arrow_rounded,
          onPressed: running ? null : onStart,
        ),
        const SizedBox(height: 6),
        Text(
          isTr ? 'Timer bitince otomatik devam eder.' : 'When timer ends, it continues automatically.',
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StepJournal extends StatelessWidget {
  final bool isTr;
  final TextEditingController controller;
  final AuraArea area;
  final VoidCallback onNext;

  const _StepJournal({super.key, required this.isTr, required this.controller, required this.area, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final question = area.journalQuestion(isTr);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(hintText: isTr ? '2–5 cümle yaz…' : 'Write 2–5 lines…'),
        ),
        const SizedBox(height: 12),
        _GlowButton(
          label: isTr ? 'Devam' : 'Next',
          icon: Icons.arrow_forward_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _StepCopyPrompt extends StatelessWidget {
  final bool isTr;
  final AuraArea area;
  final VoidCallback onFinish;

  const _StepCopyPrompt({super.key, required this.isTr, required this.area, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final p = area.prompts(isTr).first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isTr ? 'AI Prompt (kopyala ve kullan)' : 'AI Prompt (copy & use)', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(p.body, style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: p.body));
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isTr ? 'Kopyalandı ✅' : 'Copied ✅')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(isTr ? 'Kopyala' : 'Copy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlowButton(
                label: isTr ? 'Bitir' : 'Finish',
                icon: Icons.check_rounded,
                onPressed: onFinish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// COACH MANAGER (SharedPrefs persistence)
/// ------------------------------------------------------------
class AuraCoachManager extends ChangeNotifier {
  static const _prefKey = 'aura_glowup_coach_v1';
  final SharedPreferences _prefs;

  Map<String, dynamic> _root;

  AuraCoachManager._(this._prefs, this._root);

  static Future<AuraCoachManager> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.trim().isEmpty) {
      final seed = <String, dynamic>{
        'tasks': {
          'spiritual': [
            {'id': 't_sp_1', 'title': '2 dk nefes'},
            {'id': 't_sp_2', 'title': '1 cümle şükür'},
          ],
          'physical': [
            {'id': 't_ph_1', 'title': '10 dk yürüyüş'},
            {'id': 't_ph_2', 'title': '5 dk esneme'},
          ],
          'nutritionSkin': [
            {'id': 't_ns_1', 'title': '1 bardak su'},
            {'id': 't_ns_2', 'title': 'Cilt: nemlendirici'},
          ],
          'mental': [
            {'id': 't_me_1', 'title': '3 dk odak'},
            {'id': 't_me_2', 'title': '1 sayfa not'},
          ],
        },
        'days': {}, // dayKey -> areaId -> state
        'goals': [], // list
        'bonus': {}, // dayKey -> int tiny bonus
      };
      await prefs.setString(_prefKey, jsonEncode(seed));
      return AuraCoachManager._(prefs, seed);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      final fallback = <String, dynamic>{'tasks': {}, 'days': {}, 'goals': [], 'bonus': {}};
      await prefs.setString(_prefKey, jsonEncode(fallback));
      return AuraCoachManager._(prefs, fallback);
    }
    // Ensure keys
    decoded.putIfAbsent('tasks', () => {});
    decoded.putIfAbsent('days', () => {});
    decoded.putIfAbsent('goals', () => []);
    decoded.putIfAbsent('bonus', () => {});
    return AuraCoachManager._(prefs, decoded);
  }

  Future<void> _save() async {
    await _prefs.setString(_prefKey, jsonEncode(_root));
    notifyListeners();
  }

  String _areaId(AuraArea a) => a.id;

  Map<String, dynamic> _days() => (_root['days'] as Map).cast<String, dynamic>();
  Map<String, dynamic> _tasks() => (_root['tasks'] as Map).cast<String, dynamic>();
  List<dynamic> _goalsRaw() => (_root['goals'] as List).toList();
  Map<String, dynamic> _bonus() => (_root['bonus'] as Map).cast<String, dynamic>();

  /// --- Tasks ---
  List<AuraTask> tasksForArea(AuraArea area) {
    final map = _tasks();
    final list = (map[_areaId(area)] as List?)?.cast<dynamic>() ?? [];
    return list
        .whereType<Map>()
        .map((e) => AuraTask(id: (e['id'] ?? '').toString(), title: (e['title'] ?? '').toString()))
        .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
        .toList();
  }

  Future<void> addTask(AuraArea area, String title) async {
    final map = _tasks();
    final list = (map[_areaId(area)] as List?)?.cast<dynamic>() ?? [];
    final id = 't_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    list.add({'id': id, 'title': title});
    map[_areaId(area)] = list;
    _root['tasks'] = map;
    await _save();
  }

  bool isTaskChecked(String dayKey, AuraArea area, String taskId) {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaState = (day[_areaId(area)] as Map?)?.cast<String, dynamic>() ?? {};
    final checks = (areaState['checks'] as Map?)?.cast<String, dynamic>() ?? {};
    return (checks[taskId] == true);
  }

  Future<void> setTaskChecked(String dayKey, AuraArea area, String taskId, bool value) async {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaId = _areaId(area);

    final areaState = (day[areaId] as Map?)?.cast<String, dynamic>() ?? {};
    final checks = (areaState['checks'] as Map?)?.cast<String, dynamic>() ?? {};
    checks[taskId] = value;

    areaState['checks'] = checks;
    day[areaId] = areaState;
    days[dayKey] = day;
    _root['days'] = days;
    await _save();
  }

  /// --- Notes ---
  String? noteForDay(String dayKey, AuraArea area) {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaState = (day[_areaId(area)] as Map?)?.cast<String, dynamic>() ?? {};
    final note = areaState['note'];
    return note is String && note.trim().isNotEmpty ? note : null;
  }

  Future<void> setNoteForDay(String dayKey, AuraArea area, String note) async {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaId = _areaId(area);

    final areaState = (day[areaId] as Map?)?.cast<String, dynamic>() ?? {};
    areaState['note'] = note;

    day[areaId] = areaState;
    days[dayKey] = day;
    _root['days'] = days;
    await _save();
  }

  /// --- Session done ---
  bool isAreaSessionDone(String dayKey, AuraArea area) {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaState = (day[_areaId(area)] as Map?)?.cast<String, dynamic>() ?? {};
    return areaState['done'] == true;
  }

  bool canStartAreaSession(String dayKey, AuraArea area) {
    // 1 kez/gün
    return !isAreaSessionDone(dayKey, area);
  }

  String? sessionLogForDay(String dayKey, AuraArea area) {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaState = (day[_areaId(area)] as Map?)?.cast<String, dynamic>() ?? {};
    final log = areaState['log'];
    return log is String && log.trim().isNotEmpty ? log : null;
  }

  Future<void> completeAreaSession(
    String dayKey,
    AuraArea area, {
    required int durationSec,
    required String journal,
    required String log,
  }) async {
    final days = _days();
    final day = (days[dayKey] as Map?)?.cast<String, dynamic>() ?? {};
    final areaId = _areaId(area);

    final areaState = (day[areaId] as Map?)?.cast<String, dynamic>() ?? {};
    areaState['done'] = true;
    areaState['doneAt'] = DateTime.now().millisecondsSinceEpoch;
    areaState['durationSec'] = durationSec;
    areaState['journal'] = journal;
    areaState['log'] = log;

    day[areaId] = areaState;
    days[dayKey] = day;
    _root['days'] = days;

    await _save();
  }

  /// --- Tiny bonus (used by AuraLevel rewards) ---
  Future<void> giveTinyBonus(String dayKey) async {
    final b = _bonus();
    final prev = (b[dayKey] is int) ? (b[dayKey] as int) : int.tryParse('${b[dayKey]}') ?? 0;
    b[dayKey] = min(10, prev + 2);
    _root['bonus'] = b;
    await _save();
  }

  int _tinyBonus(String dayKey) {
    final b = _bonus();
    final v = b[dayKey];
    if (v is int) return v.clamp(0, 10);
    final n = int.tryParse('$v') ?? 0;
    return n.clamp(0, 10);
  }

  /// --- Scoring (0..1) ---
  double areaScore01(String dayKey, AuraArea area) {
    // session: 0.15
    // checklist tasks: up to 0.10
    // total area: 0.25  (4 alan => 1.0 => 100)
    final session = isAreaSessionDone(dayKey, area) ? 0.15 : 0.0;
    final tasks = tasksForArea(area);
    if (tasks.isEmpty) return session;

    final checked = tasks.where((t) => isTaskChecked(dayKey, area, t.id)).length;
    final taskScore = (checked / tasks.length) * 0.10;
    return (session + taskScore).clamp(0.0, 0.25);
  }

  double dayScore01(String dayKey) {
    final sum = AuraArea.values.fold<double>(0.0, (p, a) => p + areaScore01(dayKey, a));
    final bonus = _tinyBonus(dayKey) / 100.0;
    return (sum + bonus).clamp(0.0, 1.0);
  }

  double dayCompletion01(String dayKey) {
    // Completion: kaç alan session done?
    final done = AuraArea.values.where((a) => isAreaSessionDone(dayKey, a)).length;
    return (done / AuraArea.values.length).clamp(0.0, 1.0);
  }

  /// --- Streak: score >= 0.60 sayılır (60/100) ---
  bool _isGoodDay(String dayKey) => dayScore01(dayKey) >= 0.60;

  int currentStreak(String todayKey) {
    int streak = 0;
    var d = _parseDayKey(todayKey);
    for (int i = 0; i < 500; i++) {
      final k = _dayKey(d);
      if (_isGoodDay(k)) {
        streak += 1;
        d = d.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int bestStreak() {
    // son 365 gün tarama
    final today = _onlyDate(DateTime.now());
    int best = 0;
    int run = 0;
    for (int i = 0; i < 365; i++) {
      final k = _dayKey(today.subtract(Duration(days: i)));
      if (_isGoodDay(k)) {
        run += 1;
        best = max(best, run);
      } else {
        run = 0;
      }
    }
    return best;
  }

  double last7DaysAvg01(String todayKey) {
    final today = _parseDayKey(todayKey);
    double sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += dayScore01(_dayKey(today.subtract(Duration(days: i))));
    }
    return (sum / 7.0).clamp(0.0, 1.0);
  }

  /// ------------------------------------------------------------
  /// GOALS
  /// ------------------------------------------------------------
  List<AuraGoal> get goals {
    final raw = _goalsRaw();
    return raw
        .whereType<Map>()
        .map((m) => AuraGoal.fromMap(m.cast<String, dynamic>()))
        .where((g) => g.id.isNotEmpty && g.title.isNotEmpty)
        .toList();
  }

  Future<void> addGoal({
    required String title,
    required AuraArea area,
    required GoalType type,
    int? target,
    String? unit,
  }) async {
    final list = _goalsRaw();
    final id = 'g_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    list.add({
      'id': id,
      'title': title,
      'area': area.id,
      'type': type.name,
      'target': target,
      'unit': unit,
      'history': {},
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    _root['goals'] = list;
    await _save();
  }

  Future<void> updateGoal(
    String id, {
    required String title,
    required AuraArea area,
    required GoalType type,
    int? target,
    String? unit,
  }) async {
    final list = _goalsRaw();
    for (int i = 0; i < list.length; i++) {
      final m = (list[i] as Map?)?.cast<String, dynamic>();
      if (m == null) continue;
      if (m['id'] == id) {
        m['title'] = title;
        m['area'] = area.id;
        m['type'] = type.name;
        m['target'] = target;
        m['unit'] = unit;
        list[i] = m;
        break;
      }
    }
    _root['goals'] = list;
    await _save();
  }

  Future<void> deleteGoal(String id) async {
    final list = _goalsRaw();
    list.removeWhere((e) => e is Map && e['id'] == id);
    _root['goals'] = list;
    await _save();
  }

  Map<String, dynamic> _goalHistory(Map<String, dynamic> goalMap) {
    final h = goalMap['history'];
    if (h is Map) return h.cast<String, dynamic>();
    final fixed = <String, dynamic>{};
    goalMap['history'] = fixed;
    return fixed;
  }

  Map<String, dynamic>? _goalMapById(String id) {
    final list = _goalsRaw();
    for (final e in list) {
      final m = (e as Map?)?.cast<String, dynamic>();
      if (m == null) continue;
      if (m['id'] == id) return m;
    }
    return null;
  }

  bool isGoalDoneForDay(String goalId, String dayKey) {
    final gm = _goalMapById(goalId);
    if (gm == null) return false;
    final type = (gm['type'] ?? 'habit').toString();
    final h = _goalHistory(gm);
    final v = h[dayKey];
    if (type == GoalType.habit.name) return v == true;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n > 0;
  }

  int goalProgressForDay(String goalId, String dayKey) {
    final gm = _goalMapById(goalId);
    if (gm == null) return 0;
    final h = _goalHistory(gm);
    final v = h[dayKey];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Future<void> toggleHabit(String goalId, String dayKey) async {
    final list = _goalsRaw();
    for (int i = 0; i < list.length; i++) {
      final gm = (list[i] as Map?)?.cast<String, dynamic>();
      if (gm == null) continue;
      if (gm['id'] == goalId) {
        final h = _goalHistory(gm);
        final cur = h[dayKey] == true;
        h[dayKey] = !cur;
        gm['history'] = h;
        list[i] = gm;
        break;
      }
    }
    _root['goals'] = list;
    await _save();
  }

  Future<void> addProgress(String goalId, String dayKey, int delta) async {
    final list = _goalsRaw();
    for (int i = 0; i < list.length; i++) {
      final gm = (list[i] as Map?)?.cast<String, dynamic>();
      if (gm == null) continue;
      if (gm['id'] == goalId) {
        final h = _goalHistory(gm);
        final cur = (h[dayKey] is num) ? (h[dayKey] as num).toInt() : int.tryParse('${h[dayKey]}') ?? 0;
        final next = max(0, cur + delta);
        h[dayKey] = next;
        gm['history'] = h;
        list[i] = gm;
        break;
      }
    }
    _root['goals'] = list;
    await _save();
  }

  String goalStreakText(String goalId, {required bool isTr}) {
    final gm = _goalMapById(goalId);
    if (gm == null) return isTr ? '0 gün' : '0 days';
    final type = (gm['type'] ?? GoalType.habit.name).toString();
    // streak: arka arkaya günler (habit true / progress >0)
    int streak = 0;
    var d = _onlyDate(DateTime.now());
    for (int i = 0; i < 365; i++) {
      final k = _dayKey(d.subtract(Duration(days: i)));
      final v = (_goalHistory(gm)[k]);
      final ok = type == GoalType.habit.name ? (v == true) : ((v is num ? v.toInt() : int.tryParse('$v') ?? 0) > 0);
      if (ok) {
        streak += 1;
      } else {
        break;
      }
    }
    return isTr ? '$streak gün' : '$streak days';
  }
}

class AuraTask {
  final String id;
  final String title;
  AuraTask({required this.id, required this.title});
}

enum GoalType { habit, progress }

class AuraGoal {
  final String id;
  final String title;
  final AuraArea area;
  final GoalType type;
  final int? target;
  final String? unit;

  AuraGoal({
    required this.id,
    required this.title,
    required this.area,
    required this.type,
    this.target,
    this.unit,
  });

  static AuraGoal fromMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final title = (m['title'] ?? '').toString();
    final areaId = (m['area'] ?? AuraArea.mental.id).toString();
    final typeStr = (m['type'] ?? GoalType.habit.name).toString();
    final target = (m['target'] is num) ? (m['target'] as num).toInt() : int.tryParse('${m['target']}');
    final unit = (m['unit'] is String) ? (m['unit'] as String) : null;

    return AuraGoal(
      id: id,
      title: title,
      area: auraAreaFromId(areaId),
      type: typeStr == GoalType.progress.name ? GoalType.progress : GoalType.habit,
      target: target,
      unit: unit,
    );
  }

  
}
AuraArea auraAreaFromId(String id) {
  for (final a in AuraArea.values) {
    if (a.id == id) return a;
  }
  return AuraArea.mental;
}

/// ------------------------------------------------------------
/// AREAS MODEL + PROMPTS
/// ------------------------------------------------------------
enum AuraArea { spiritual, physical, nutritionSkin, mental }

extension AuraAreaX on AuraArea {
  String get id {
    switch (this) {
      case AuraArea.spiritual:
        return 'spiritual';
      case AuraArea.physical:
        return 'physical';
      case AuraArea.nutritionSkin:
        return 'nutritionSkin';
      case AuraArea.mental:
        return 'mental';
    }
  }

  static AuraArea fromId(String id) {
    for (final a in AuraArea.values) {
      if (a.id == id) return a;
    }
    return AuraArea.mental;
  }

  String title(bool tr) {
    switch (this) {
      case AuraArea.spiritual:
        return tr ? 'Ruhsal' : 'Spiritual';
      case AuraArea.physical:
        return tr ? 'Fiziksel' : 'Physical';
      case AuraArea.nutritionSkin:
        return tr ? 'Beslenme & Cilt' : 'Nutrition & Skin';
      case AuraArea.mental:
        return tr ? 'Mental' : 'Mental';
    }
  }

  String subtitle(bool tr) {
    switch (this) {
      case AuraArea.spiritual:
        return tr ? 'Sakinlik, niyet, şükür.' : 'Calm, intention, gratitude.';
      case AuraArea.physical:
        return tr ? 'Enerji, güç, hareket.' : 'Energy, strength, movement.';
      case AuraArea.nutritionSkin:
        return tr ? 'Su, beslenme, bakım.' : 'Water, nutrition, care.';
      case AuraArea.mental:
        return tr ? 'Odak, üretkenlik, zihin.' : 'Focus, productivity, mind.';
    }
  }

  String sessionPrompt(bool tr) {
    switch (this) {
      case AuraArea.spiritual:
        return tr ? '3–5 dk: nefes + niyet. Zihni yumuşat.' : '3–5 min: breath + intention. Soften your mind.';
      case AuraArea.physical:
        return tr ? '3–5 dk: mini ısınma. Vücudu uyandır.' : '3–5 min: micro warmup. Wake your body.';
      case AuraArea.nutritionSkin:
        return tr ? '3–5 dk: su + bakım. Kendine yatırım.' : '3–5 min: water + care. Invest in yourself.';
      case AuraArea.mental:
        return tr ? '3–5 dk: odak. Bugünün tek hedefi.' : '3–5 min: focus. One target for today.';
    }
  }

  String journalQuestion(bool tr) {
    switch (this) {
      case AuraArea.spiritual:
        return tr ? 'Bugün hangi duyguyu büyütmek istiyorum?' : 'What feeling do I want to grow today?';
      case AuraArea.physical:
        return tr ? 'Bugün vücudum benden ne istiyor?' : 'What does my body need today?';
      case AuraArea.nutritionSkin:
        return tr ? 'Bugün kendime hangi küçük bakımı yapacağım?' : 'What small care will I do today?';
      case AuraArea.mental:
        return tr ? 'Bugünün 1 net hedefi ne?' : 'What is the one clear goal today?';
    }
  }

  List<CoachPrompt> prompts(bool tr) {
    switch (this) {
      case AuraArea.spiritual:
        return [
          CoachPrompt(
            title: tr ? 'Derinleşme Promptu' : 'Deepening Prompt',
            body: tr
                ? 'Bana bugün için 3 dakikalık bir nefes + niyet rutini yaz. Çok basit olsun. Sonunda 1 cümlelik bir “niyet” ver ve 1 cümlelik bir “şükür” sorusu sor.'
                : 'Write a simple 3-minute breath + intention routine for today. End with a one-line intention and one gratitude question.',
          ),
          CoachPrompt(
            title: tr ? 'Duygu Dönüştürme' : 'Emotion Reframe',
            body: tr
                ? 'Şu duyguyu yaşıyorum: (…)\nBunu daha sağlıklı bir bakışa çevirmem için 5 kısa cümle yaz. 1 tane de mini eylem öner.'
                : 'I feel: (…)\nWrite 5 short reframes and suggest 1 tiny action.',
          ),
        ];
      case AuraArea.physical:
        return [
          CoachPrompt(
            title: tr ? 'Mini Antrenman' : 'Micro Workout',
            body: tr
                ? 'Evde ekipmansız 5 dakikalık mikro antrenman yaz. Başlangıç seviyesi. Set/süre net olsun. Bitince 1 cümle motive eden kapanış yaz.'
                : 'Give me a 5-minute beginner micro workout at home, no equipment. Clear sets/timing. End with 1 motivational line.',
          ),
          CoachPrompt(
            title: tr ? 'Esneme' : 'Stretching',
            body: tr
                ? 'Bel/omuz ağırlıklı 4 dakikalık esneme rutini yaz. Her hareket için süre ve nefes ipucu ekle.'
                : 'Write a 4-minute stretch routine focusing on back/shoulders. Add timing + breathing cue.',
          ),
        ];
      case AuraArea.nutritionSkin:
        return [
          CoachPrompt(
            title: tr ? 'Beslenme Planı' : 'Nutrition Plan',
            body: tr
                ? 'Bugün için basit bir beslenme planı yap. Kahvaltı/öğle/akşam + 1 ara öğün. Protein ve su hatırlatması ekle. Uygulaması kolay olsun.'
                : 'Make a simple meal plan for today: breakfast/lunch/dinner + 1 snack. Add protein + water reminder. Keep it easy.',
          ),
          CoachPrompt(
            title: tr ? 'Cilt Bakımı' : 'Skin Routine',
            body: tr
                ? 'Cildim: (kuru/yağlı/karma). Bugün için 2 dakikalık sabah + 2 dakikalık akşam rutin yaz. Çok temel ürünlerle.'
                : 'My skin: (dry/oily/combination). Give me a 2-min morning + 2-min night routine with basic products.',
          ),
        ];
      case AuraArea.mental:
        return [
          CoachPrompt(
            title: tr ? 'Odak Planı' : 'Focus Plan',
            body: tr
                ? 'Bugün tek hedefim: (…)\nBunu bitirmem için 25 dakikalık 2 pomodoro planı yaz. Dikkat dağıtanları azaltmak için 3 kural ekle.'
                : 'My one goal today: (…)\nCreate a plan with 2x 25-minute pomodoros. Add 3 rules to reduce distractions.',
          ),
          CoachPrompt(
            title: tr ? 'Zihin Temizliği' : 'Mind Clear',
            body: tr
                ? 'Kafam karışık: (…)\nBunu netleştirmek için 6 soruluk bir yazma egzersizi ver. Sorular kısa ama etkili olsun.'
                : 'My mind is messy: (…)\nGive me a 6-question journaling exercise. Short but powerful questions.',
          ),
        ];
    }
  }
}

class CoachPrompt {
  final String title;
  final String body;
  CoachPrompt({required this.title, required this.body});
}

/// ------------------------------------------------------------
/// THEME + UI
/// ------------------------------------------------------------
class AuraTheme {
  static ThemeData theme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0E0010),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD36A), brightness: Brightness.dark),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: const Color(0xFF160016).withOpacity(0.94),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.22))),
      ),
    );
  }
}

class S {
  static const Map<String, Map<String, String>> _k = {
    'appName': {'en': 'Aura GlowUp', 'tr': 'Aura GlowUp'},
    'today': {'en': 'Today', 'tr': 'Bugün'},
    'areas': {'en': 'Areas', 'tr': 'Bölümler'},
    'goals': {'en': 'Goals', 'tr': 'Hedefler'},
    'profile': {'en': 'Profile', 'tr': 'Profil'},

    'settings': {'en': 'Settings', 'tr': 'Ayarlar'},
    'auraLevel': {'en': 'Aura Level', 'tr': 'Aura Level'},
    'auraMaxed': {'en': 'MAXED', 'tr': 'MAX'},
    'auraRunDone': {'en': 'Done today', 'tr': 'Bugün tamamlandı'},
    'startAuraRun': {'en': 'Start Aura Run', 'tr': 'Aura Level Başlat'},
    'auraPoints': {'en': 'Aura points', 'tr': 'Aura puanı'},
    'rank': {'en': 'Rank', 'tr': 'Rütbe'},
    'resetAura': {'en': 'Reset Aura Levels', 'tr': 'Aura Level Sıfırla'},
    'cancel': {'en': 'Cancel', 'tr': 'İptal'},
    'delete': {'en': 'Delete', 'tr': 'Sil'},
    'auraScore': {'en': 'Aura score', 'tr': 'Aura puanı'},
    'profileTitle': {'en': 'Your aura', 'tr': 'Auran'},
    'chooseLanguage': {'en': 'Choose language', 'tr': 'Dil seç'},

    'focusAreas': {'en': 'Focus areas', 'tr': 'Odak alanları'},
    'startSession': {'en': 'Start Session', 'tr': 'Session Başlat'},
    'doneToday': {'en': 'Done today', 'tr': 'Bugün tamam'},
    'notToday': {'en': 'Not available', 'tr': 'Şu an değil'},
    'open': {'en': 'Open', 'tr': 'Aç'},
    'aiPrompts': {'en': 'AI Prompts', 'tr': 'AI Promptları'},
    'checklist': {'en': 'Checklist', 'tr': 'Checklist'},
    'addTask': {'en': 'Add task', 'tr': 'Görev ekle'},
    'notes': {'en': 'Notes', 'tr': 'Notlar'},
    'save': {'en': 'Save', 'tr': 'Kaydet'},
    'sessionLog': {'en': 'Session log', 'tr': 'Session kaydı'},
    'goToday': {'en': 'Go today', 'tr': 'Bugüne dön'},
  };

  static String t(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;
    return _k[key]?[code] ?? _k[key]?['en'] ?? key;
  }
}

class FancyBackground extends StatefulWidget {
  final bool animated;
  const FancyBackground({super.key, this.animated = false});

  @override
  State<FancyBackground> createState() => _FancyBackgroundState();
}

class _FancyBackgroundState extends State<FancyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController c;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    if (widget.animated) c.repeat(reverse: true);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final t = widget.animated ? c.value : 0.0;
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.3),
              radius: 1.2,
              colors: [Color(0xFF2B0030), Color(0xFF0E0010)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(left: -80 + 12 * t, top: -60 + 10 * t, child: _GlowBlob(color: const Color(0xFFFFD36A).withOpacity(0.18), size: 240)),
              Positioned(right: -90 + 14 * t, top: 120 - 8 * t, child: _GlowBlob(color: const Color(0xFFFF4FD8).withOpacity(0.12), size: 280)),
              Positioned(right: -120 - 10 * t, bottom: -100 + 10 * t, child: _GlowBlob(color: const Color(0xFF6A9CFF).withOpacity(0.10), size: 320)),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StarDustPainter(seed: 7, phase: t),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StarDustPainter extends CustomPainter {
  final int seed;
  final double phase;
  _StarDustPainter({required this.seed, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    final p = Paint()..color = Colors.white.withOpacity(0.06);
    for (int i = 0; i < 90; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      final dx = sin((x / 120.0) + phase * 2 * pi) * 1.2;
      final dy = cos((y / 140.0) + phase * 2 * pi) * 1.2;
      final rad = r.nextDouble() * 1.6 + 0.2;
      canvas.drawCircle(Offset(x + dx, y + dy), rad, p);
    }
  }

  @override
  bool shouldRepaint(covariant _StarDustPainter oldDelegate) => oldDelegate.phase != phase;
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 16),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onSettings;

  const _TopBar({required this.title, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD36A), Color(0x33FFD36A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD36A).withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 20),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(onPressed: onSettings, icon: const Icon(Icons.settings_outlined)),
        ],
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GlowButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: p.withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool glow;

  const _Pill({required this.text, required this.icon, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: p.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AreaIcon extends StatelessWidget {
  final AuraArea area;
  final bool big;
  const _AreaIcon({required this.area, this.big = false});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (area) {
      case AuraArea.spiritual:
        icon = Icons.self_improvement_rounded;
        break;
      case AuraArea.physical:
        icon = Icons.fitness_center_rounded;
        break;
      case AuraArea.nutritionSkin:
        icon = Icons.spa_rounded;
        break;
      case AuraArea.mental:
        icon = Icons.psychology_alt_rounded;
        break;
    }

    return Container(
      width: big ? 46 : 38,
      height: big ? 46 : 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Icon(icon, size: big ? 24 : 20),
    );
  }
}

class _Sheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _Sheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Language picker + Settings
/// ------------------------------------------------------------
class LanguagePickScreen extends StatelessWidget {
  final void Function(String code) onPick;
  const LanguagePickScreen({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FancyBackground(animated: true),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.t(context, 'chooseLanguage'), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onPick('en'),
                            child: const Text('English'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onPick('tr'),
                            child: const Text('Türkçe'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ... SettingsScreen içindeydin, buradan sonra ekle:

class SettingsScreen extends StatelessWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final current = controller.state.localeCode ?? 'en';
    return Scaffold(
      body: Stack(
        children: [
          const FancyBackground(animated: true),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        S.t(context, 'settings'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    child: DropdownButtonFormField<String>(
                      value: current,
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        controller.setLocale(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'tr'
                          ? 'Dil değişimi anında uygulanır.'
                          : 'Language changes apply instantly.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontWeight: FontWeight.w700,
                      ),
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

/// ------------------------------------------------------------
/// Date helpers
/// ------------------------------------------------------------
DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

String _dayKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final da = d.day.toString().padLeft(2, '0');
  return '$y-$m-$da';
}

DateTime _parseDayKey(String key) {
  // expects YYYY-MM-DD
  final parts = key.split('-');
  if (parts.length != 3) return _onlyDate(DateTime.now());
  final y = int.tryParse(parts[0]) ?? DateTime.now().year;
  final m = int.tryParse(parts[1]) ?? DateTime.now().month;
  final d = int.tryParse(parts[2]) ?? DateTime.now().day;
  return DateTime(y, m, d);
}

String _prettyDate(BuildContext context, DateTime d) {
  // Locale-aware nice date (includes weekday)
  final loc = MaterialLocalizations.of(context);
  return loc.formatFullDate(d);
}
