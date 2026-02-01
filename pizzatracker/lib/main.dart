// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_widget/home_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() {
    runApp(const AppRoot());
  }, (e, st) {
    debugPrint("ZONED ERROR: $e\n$st");
  });
}

/// ============================================================
/// SINGLE MaterialApp ROOT (nested MaterialApp yok)
/// ============================================================
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  static const bg = Color(0xFF070B14);
  static const panel = Color(0xFF0E1424);
  static const stroke = Color(0xFF1E2A44);

  static const neonBlue = Color(0xFF2D6BFF);
  static const neonCyan = Color(0xFF34D3FF);
  static const neonGreen = Color(0xFF2DFF8B);
  static const neonAmber = Color(0xFFFFC857);
  static const neonRed = Color(0xFFFF375F);
  static const textSoft = Color(0xFFB9C2D6);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Washington Pizza Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: neonBlue,
          secondary: neonCyan,
          surface: panel,
        ),
      ),
      home: const BootGate(),
    );
  }
}

/// ============================================================
/// BOOT GATE: İlk frame’i garanti basar.
/// Sonra Firebase + HomeWidget init (tamamı try/catch + timeout)
/// ============================================================
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  bool _firebaseOk = false;
  String? _firebaseErr;

  bool _widgetOk = false;
  String? _widgetErr;

  bool _bootDone = false;

  // Widget config (senin değerlerin)
  static const String appGroupId = "group.tunahanoguz.pizzatracker";
  static const String iOSWidgetName = "MyHomeWidget";
  static const String androidWidgetName = "MyHomeWidget";
  static const String dataKey = "text_from_flutter_app";
  static const String widgetPayloadKey = "wpt_widget_payload_v1";

  // Eğer HomeWidget şüpheliyse bunu false yapıp test et:
  static const bool enableWidgets = true;

  @override
  void initState() {
    super.initState();
    // İlk frame kesin çizilsin diye init'i microtask ile başlatıyoruz
    Future.microtask(_boot);
  }

  Future<void> _boot() async {
    // 1) Firebase init (timeout + try/catch)
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      _firebaseOk = true;
    } catch (e, st) {
      _firebaseOk = false;
      _firebaseErr = "Firebase init failed: $e";
      debugPrint("Firebase init error: $e\n$st");
    }

    // 2) HomeWidget init (tamamen optional)
    if (enableWidgets) {
      try {
        // Sadece iOS/Android’de çalıştır
        if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
          await HomeWidget.setAppGroupId(appGroupId);
          _widgetOk = true;

          // Basit test write (crash olmasın diye try/catch)
          try {
            await HomeWidget.saveWidgetData<String>(dataKey, "BOOT OK");
            await HomeWidget.saveWidgetData<String>(
              widgetPayloadKey,
              jsonEncode({
                "boot": "ok",
                "ts": DateTime.now().toIso8601String(),
              }),
            );
            await HomeWidget.updateWidget(iOSName: iOSWidgetName, androidName: androidWidgetName);
          } catch (e) {
            // write fail olsa bile widget init ok say
            debugPrint("HomeWidget write/update warning: $e");
          }
        } else {
          _widgetOk = true; // web/desktop: ignore
        }
      } catch (e, st) {
        _widgetOk = false;
        _widgetErr = "HomeWidget init failed: $e";
        debugPrint("HomeWidget init error: $e\n$st");
      }
    } else {
      _widgetOk = true; // intentionally disabled
    }

    _bootDone = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // ✅ İlk frame’i garanti basan ekran (white screen’i kırmak için)
    if (!_bootDone) {
      return const _BootSplash();
    }

    // Firebase ok ise app’e gir, değilse SAFE MODE
    if (_firebaseOk) {
      return HomeShell(
        widgetOk: _widgetOk,
        widgetErr: _widgetErr,
        onForceSafeMode: () {
          setState(() {
            _firebaseOk = false;
            _firebaseErr = "Forced safe mode by user";
          });
        },
      );
    }

    return SafeModeScreen(
      title: "SAFE MODE (Flutter OK)",
      message: _firebaseErr ?? "Firebase not available",
      extra: enableWidgets
          ? "Widget: ${_widgetOk ? "OK" : "FAIL"}\n${_widgetErr ?? ""}"
          : "Widget: disabled (enableWidgets=false)",
      onRetry: () {
        setState(() {
          _bootDone = false;
          _firebaseOk = false;
          _firebaseErr = null;
          _widgetOk = false;
          _widgetErr = null;
        });
        Future.microtask(_boot);
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppRoot.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.local_pizza, size: 56, color: AppRoot.neonAmber),
                SizedBox(height: 14),
                Text(
                  "BOOTING… (Flutter frame should appear)",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                SizedBox(height: 10),
                Text(
                  "If you STILL see a pure white screen,\nproblem is iOS Runner/Storyboard (not Dart).",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppRoot.textSoft, fontSize: 12),
                ),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// SAFE MODE SCREEN
/// ============================================================
class SafeModeScreen extends StatelessWidget {
  final String title;
  final String message;
  final String extra;
  final VoidCallback onRetry;

  const SafeModeScreen({
    super.key,
    required this.title,
    required this.message,
    required this.extra,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppRoot.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 46, color: AppRoot.neonAmber),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppRoot.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppRoot.stroke.withOpacity(0.85)),
                    ),
                    child: Text(
                      extra,
                      style: const TextStyle(fontSize: 12, color: AppRoot.textSoft, height: 1.25),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry Boot"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// APP HOME (Firestore reads are guarded, UI never crashes)
/// ============================================================
class HomeShell extends StatefulWidget {
  final bool widgetOk;
  final String? widgetErr;
  final VoidCallback onForceSafeMode;

  const HomeShell({
    super.key,
    required this.widgetOk,
    required this.widgetErr,
    required this.onForceSafeMode,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum SignalStatus { spike, quieter, nominal, quiet }

SignalStatus parseStatus(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'spike':
      return SignalStatus.spike;
    case 'quieter':
      return SignalStatus.quieter;
    case 'nominal':
      return SignalStatus.nominal;
    case 'quiet':
      return SignalStatus.quiet;
    default:
      return SignalStatus.nominal;
  }
}

class _HomeShellState extends State<HomeShell> {
  int selectedDayIndex = 6;
  bool liveMode = true;

  int nehPercent = 0;
  StreamSubscription? _nehSub;

  @override
  void initState() {
    super.initState();

    // Firestore stream: hata olursa sadece logla, app düşmesin
    _nehSub = FirebaseFirestore.instance.collection('app').doc('state').snapshots().listen(
      (snap) {
        final d = snap.data() ?? {};
        final v = (d['nehPercent'] is num) ? (d['nehPercent'] as num).round() : 0;
        if (mounted) setState(() => nehPercent = v.clamp(0, 100));
      },
      onError: (e, st) => debugPrint("NEH stream error: $e\n$st"),
    );
  }

  @override
  void dispose() {
    _nehSub?.cancel();
    super.dispose();
  }

  String get dayKey {
    if (liveMode) return "LIVE";
    const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    return days[selectedDayIndex.clamp(0, 6)];
  }

  Future<void> _manualRefresh() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('app').doc('state').get();
      final d = snap.data() ?? {};
      final v = (d['nehPercent'] is num) ? (d['nehPercent'] as num).round() : 0;
      if (mounted) setState(() => nehPercent = v.clamp(0, 100));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed')));
      }
    } catch (e, st) {
      debugPrint("manualRefresh error: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refresh failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _TopBar(widgetOk: widget.widgetOk, widgetErr: widget.widgetErr)),
              SliverToBoxAdapter(child: _HeroBlurb(dayKey: dayKey)),
              SliverToBoxAdapter(
                child: _TimelineRow(
                  liveMode: liveMode,
                  selectedDayIndex: selectedDayIndex,
                  onToggleLive: () => setState(() => liveMode = !liveMode),
                  onSelectDay: (i) => setState(() {
                    selectedDayIndex = i;
                    liveMode = false;
                  }),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _GaugeCard(nehPercent: nehPercent),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: "PIZZERIAS",
                  subtitle: "Firestore collection: pizzerias (read-only)",
                  icon: Icons.local_pizza,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _PlacesGrid(
                    collection: "pizzerias",
                    dayKey: dayKey,
                    limit: 6,
                    columns: 2,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: "GAY BAR REPORT",
                  subtitle: "Firestore collection: gayBars (read-only)",
                  icon: Icons.local_bar,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _PlacesList(
                    collection: "gayBars",
                    dayKey: dayKey,
                    limit: 2,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: OutlinedButton.icon(
                    onPressed: widget.onForceSafeMode,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text("Force Safe Mode (debug)"),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- UI Pieces ----------------

class _TopBar extends StatelessWidget {
  final bool widgetOk;
  final String? widgetErr;
  const _TopBar({required this.widgetOk, required this.widgetErr});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          const _NeonIconBadge(icon: Icons.local_pizza, glowColor: AppRoot.neonAmber),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "WASHINGTON PIZZA TRACKER",
              style: TextStyle(fontSize: 16, letterSpacing: 1.2, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: widgetOk ? "Widget: OK" : "Widget: FAIL\n${widgetErr ?? ""}",
            child: Icon(widgetOk ? Icons.widgets_outlined : Icons.widgets, color: widgetOk ? AppRoot.neonGreen : AppRoot.neonRed),
          ),
        ],
      ),
    );
  }
}

class _HeroBlurb extends StatelessWidget {
  final String dayKey;
  const _HeroBlurb({required this.dayKey});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppRoot.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppRoot.stroke.withOpacity(0.8)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bolt, color: AppRoot.neonCyan, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "If this screen shows up, Flutter is running ✅\n"
                "Mode: $dayKey • Data: Firestore read-only.",
                style: const TextStyle(color: AppRoot.textSoft, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final bool liveMode;
  final int selectedDayIndex;
  final VoidCallback onToggleLive;
  final ValueChanged<int> onSelectDay;

  const _TimelineRow({
    required this.liveMode,
    required this.selectedDayIndex,
    required this.onToggleLive,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1020),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppRoot.stroke.withOpacity(0.8)),
        ),
        child: Row(
          children: [
            Row(
              children: const [
                Icon(Icons.timeline, color: AppRoot.neonGreen, size: 18),
                SizedBox(width: 8),
                Text("TIMELINE:", style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _DayPill(text: "LIVE", active: liveMode, activeColor: AppRoot.neonGreen, onTap: onToggleLive),
                    const SizedBox(width: 8),
                    for (int i = 0; i < days.length; i++) ...[
                      _DayPill(
                        text: days[i],
                        active: !liveMode && selectedDayIndex == i,
                        activeColor: AppRoot.neonBlue,
                        onTap: () => onSelectDay(i),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String text;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _DayPill({
    required this.text,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? activeColor : AppRoot.stroke.withOpacity(0.9), width: 1),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final int nehPercent;
  const _GaugeCard({required this.nehPercent});

  String get nehTitle {
    if (nehPercent < 30) return "NOTHING EVER HAPPENS";
    if (nehPercent < 65) return "SOMETHING MIGHT HAPPEN";
    if (nehPercent < 90) return "SOMETHING IS HAPPENING";
    return "IT HAPPENED";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppRoot.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppRoot.stroke.withOpacity(0.9)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: 130,
            child: CustomPaint(
              painter: _GaugePainter(value: nehPercent.clamp(0, 100).toDouble()),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$nehPercent",
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppRoot.neonGreen),
                      ),
                      const SizedBox(height: 2),
                      const Text("%", style: TextStyle(color: AppRoot.textSoft)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("NEH SIGNAL", style: TextStyle(letterSpacing: 1.3, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(nehTitle, style: const TextStyle(color: AppRoot.textSoft, height: 1.2)),
                const SizedBox(height: 10),
                const Text(
                  "If values don’t change, check Firestore docs:\napp/state nehPercent",
                  style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceItem {
  final String id;
  final String name;
  final double distanceMi;
  final SignalStatus status;
  final int magnitudePercent;

  PlaceItem({
    required this.id,
    required this.name,
    required this.distanceMi,
    required this.status,
    required this.magnitudePercent,
  });

  factory PlaceItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PlaceItem(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      distanceMi: (d['distanceMi'] is num) ? (d['distanceMi'] as num).toDouble() : 0.0,
      status: parseStatus(d['status']?.toString()),
      magnitudePercent: (d['magnitudePercent'] is num) ? (d['magnitudePercent'] as num).round() : 0,
    );
  }
}

class _PlacesGrid extends StatelessWidget {
  final String collection;
  final String dayKey;
  final int limit;
  final int columns;

  const _PlacesGrid({
    required this.collection,
    required this.dayKey,
    required this.limit,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final items = docs.map((e) => PlaceItem.fromDoc(e)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        // placeholder doldur
        while (items.length < limit) {
          items.add(PlaceItem(
            id: 'placeholder_${items.length}',
            name: snap.hasError ? 'ERROR' : 'LOADING…',
            distanceMi: 0,
            status: SignalStatus.nominal,
            magnitudePercent: 0,
          ));
        }
        items.length = min(items.length, limit);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            return _PlaceCard(item: items[i], dayKey: dayKey, rainbowBorder: i == 0);
          },
        );
      },
    );
  }
}

class _PlacesList extends StatelessWidget {
  final String collection;
  final String dayKey;
  final int limit;

  const _PlacesList({
    required this.collection,
    required this.dayKey,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final items = docs.map((e) => PlaceItem.fromDoc(e)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        while (items.length < limit) {
          items.add(PlaceItem(
            id: 'placeholder_list_${items.length}',
            name: snap.hasError ? 'ERROR' : 'LOADING…',
            distanceMi: 0,
            status: SignalStatus.nominal,
            magnitudePercent: 0,
          ));
        }
        items.length = min(items.length, limit);

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _PlaceCard(item: items[i], dayKey: dayKey, rainbowBorder: i == 0),
              if (i != items.length - 1) const SizedBox(height: 12),
            ]
          ],
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceItem item;
  final String dayKey;
  final bool rainbowBorder;

  const _PlaceCard({required this.item, required this.dayKey, required this.rainbowBorder});

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    final magnitude = item.magnitudePercent;

    final bars = _fakeBars(
      seed: "${item.id}|${item.name}|${status.name}|$magnitude|$dayKey",
      status: status,
      magnitude: magnitude,
    );

    final chipColor = _chipStroke(status);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rainbowBorder ? AppRoot.neonGreen : AppRoot.stroke.withOpacity(0.9),
          width: rainbowBorder ? 2 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: rainbowBorder
              ? [
                  AppRoot.neonBlue.withOpacity(0.25),
                  AppRoot.panel,
                  AppRoot.neonCyan.withOpacity(0.18),
                ]
              : [
                  const Color(0xFF0B1020),
                  AppRoot.panel,
                ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_pizza, size: 18, color: AppRoot.neonAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${item.distanceMi.toStringAsFixed(1)} mi",
                style: const TextStyle(color: AppRoot.textSoft, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: chipColor, width: 1),
            ),
            child: Text(
              _label(status, magnitude),
              style: TextStyle(color: chipColor, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "POPULAR TIMES",
            style: TextStyle(color: AppRoot.textSoft, fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          _MiniBarChart(values: bars),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  const _MiniBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++) ...[
            Expanded(
              child: Container(
                height: max(6, values[i] * 58),
                decoration: BoxDecoration(
                  color: AppRoot.neonBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i != values.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

List<double> _fakeBars({
  required String seed,
  required SignalStatus status,
  required int magnitude,
}) {
  final s = seed.codeUnits.fold<int>(0, (p, e) => p + e);
  final rnd = Random(s);

  final base = List<double>.generate(12, (i) {
    final t = i / 11.0;
    final peak = exp(-pow((t - 0.68) * 3.0, 2));
    return (0.20 + 0.55 * peak).clamp(0.0, 1.0);
  });

  double mult;
  switch (status) {
    case SignalStatus.spike:
      mult = 1.10 + (magnitude / 300.0);
      break;
    case SignalStatus.quieter:
      mult = 0.75 - (magnitude / 400.0);
      break;
    case SignalStatus.quiet:
      mult = 0.60;
      break;
    case SignalStatus.nominal:
    default:
      mult = 0.92;
      break;
  }
  mult = mult.clamp(0.35, 1.6);

  return List<double>.generate(12, (i) {
    final jitter = (rnd.nextDouble() - 0.5) * 0.18;
    return (base[i] * mult + jitter).clamp(0.05, 1.0);
  });
}

Color _chipStroke(SignalStatus s) {
  switch (s) {
    case SignalStatus.spike:
      return AppRoot.neonRed;
    case SignalStatus.quieter:
      return AppRoot.neonBlue;
    case SignalStatus.nominal:
      return AppRoot.neonGreen;
    case SignalStatus.quiet:
      return AppRoot.neonCyan;
  }
}

String _label(SignalStatus s, int magnitudePercent) {
  switch (s) {
    case SignalStatus.spike:
      return '${magnitudePercent}% SPIKE';
    case SignalStatus.quieter:
      return '${magnitudePercent}% QUIETER';
    case SignalStatus.nominal:
      return 'NOMINAL';
    case SignalStatus.quiet:
      return 'QUIET';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: [
          _NeonIconBadge(icon: icon, glowColor: AppRoot.neonBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppRoot.textSoft, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonIconBadge extends StatelessWidget {
  final IconData icon;
  final Color glowColor;
  const _NeonIconBadge({required this.icon, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: glowColor.withOpacity(0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: glowColor.withOpacity(0.8)),
        boxShadow: [BoxShadow(color: glowColor.withOpacity(0.18), blurRadius: 16, spreadRadius: 1)],
      ),
      child: Icon(icon, color: glowColor),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  _GaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.92);
    final radius = min(size.width, size.height) * 0.75;

    const start = pi;
    const sweep = pi;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = AppRoot.stroke.withOpacity(0.6)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, bgPaint);

    final segs = [
      _Seg(0, 30, AppRoot.neonGreen.withOpacity(0.85)),
      _Seg(30, 65, AppRoot.neonAmber.withOpacity(0.90)),
      _Seg(65, 90, const Color(0xFFFF8A3D)),
      _Seg(90, 100, AppRoot.neonRed.withOpacity(0.92)),
    ];

    final segPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;

    for (final seg in segs) {
      final a0 = start + sweep * (seg.from / 100.0);
      final a1 = sweep * ((seg.to - seg.from) / 100.0);
      segPaint.color = seg.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), a0, a1, false, segPaint);
    }

    final needleAngle = start + sweep * (value.clamp(0, 100) / 100.0);
    final needleLen = radius * 0.88;
    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = AppRoot.neonCyan.withOpacity(0.9);

    final p2 = Offset(center.dx + cos(needleAngle) * needleLen, center.dy + sin(needleAngle) * needleLen);
    canvas.drawLine(center, p2, needlePaint);

    canvas.drawCircle(center, 10, Paint()..color = AppRoot.neonCyan.withOpacity(0.35));
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF0B1020));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.value != value;
}

class _Seg {
  final double from;
  final double to;
  final Color color;
  _Seg(this.from, this.to, this.color);
}
