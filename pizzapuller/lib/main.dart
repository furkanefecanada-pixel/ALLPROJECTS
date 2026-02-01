// lib/main.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:home_widget/home_widget.dart';




void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };

    runApp(const PizzaTrackerApp());
  }, (e, st) {
    debugPrint("ZONED ERROR: $e\n$st");
  });
}

/// ============================================================
/// WASHINGTON PIZZA TRACKER (Firebase + Neon UI + Widget Config)
/// - Reads:
///   app/state -> { nehPercent: number, nehLabel: string, updatedAt: timestamp }
///   pizzerias/* -> { name, distanceMi, status, magnitudePercent, updatedAt }
///   gayBars/*   -> same
///
/// - Overview:
///   - NEH card title now uses nehLabel (NOT "NEH %")
///   - Widget Setup card:
///       choose source (NEH / Pizzerias / Gay Bars)
///       pick an item
///       push selection to Home Screen widget via App Group
///
/// - Home widget data keys are written via home_widget package
/// ============================================================
class PizzaTrackerApp extends StatelessWidget {
  const PizzaTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Pizza Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: _UI.bg,
        colorScheme: const ColorScheme.dark(
          background: _UI.bg,
          surface: _UI.panel,
          primary: _UI.neonBlue,
          secondary: _UI.neonGreen,
          error: _UI.neonRed,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
          headlineMedium: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
          titleLarge: TextStyle(fontWeight: FontWeight.w900),
          titleMedium: TextStyle(fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(height: 1.25),
          bodyMedium: TextStyle(height: 1.25),
        ),
      ),
      home: const FirebaseGate(),
    );
  }
}

class FirebaseGate extends StatefulWidget {
  const FirebaseGate({super.key});

  @override
  State<FirebaseGate> createState() => _FirebaseGateState();
}

class _FirebaseGateState extends State<FirebaseGate> {
  bool _ready = false;
  String? _err;

  static const String appGroupId = "group.com.efe.lifenotes"; // change to your App Group ID

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));

      // HomeWidget: bind App Group (iOS) / prefs (Android)
      try {
        await HomeWidget.setAppGroupId(appGroupId);
      } catch (e) {
        // don’t crash app if plugin isn’t ready on some platforms
        debugPrint("HomeWidget.setAppGroupId error: $e");
      }

      _ready = true;
    } catch (e, st) {
      _err = "Firebase.initializeApp FAILED:\n$e";
      debugPrint("Firebase init error: $e\n$st");
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) return _ErrorScreen(message: _err!);
    if (!_ready) return const _LoadingScreen();
    return const HomeShell();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 14),
              Text("Booting…", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _UI.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 50, color: _UI.neonRed),
                  const SizedBox(height: 12),
                  const Text(
                    "SAFE MODE",
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "iOS fix checklist:\n- GoogleService-Info.plist correct target\n- Bundle ID matches Firebase app\n- Pods installed (pod install)\nThen run again.",
                    style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.35),
                    textAlign: TextAlign.center,
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
/// HOME SHELL (Bottom Nav)
/// ============================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const PlacesListPage(
        title: "Pizzerias",
        collection: "pizzerias",
        leadingEmoji: "🍕",
        accent: _UI.neonBlue,
        borderGlow: _UI.glowBlue,
      ),
      const PlacesListPage(
        title: "Gay Bars",
        collection: "gayBars",
        leadingEmoji: "🍸",
        accent: _UI.neonPink,
        borderGlow: _UI.glowPink,
      ),
      const WidgetPage(),
    ];

    return Scaffold(
      body: pages[_i],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _UI.panel2,
          border: Border(top: BorderSide(color: _UI.stroke, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            backgroundColor: _UI.panel2,
            indicatorColor: _UI.stroke.withOpacity(0.35),
            selectedIndex: _i,
            onDestinationSelected: (v) => setState(() => _i = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                label: "Overview",
              ),
              NavigationDestination(
                icon: Icon(Icons.local_pizza_outlined),
                label: "Pizzerias",
              ),
              NavigationDestination(
                icon: Icon(Icons.local_bar_outlined),
                label: "Bars",
              ),
              NavigationDestination(
                icon: Icon(Icons.widgets_outlined),
                label: "Widget",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// DASHBOARD
/// ============================================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 450)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: _UI.bg,
              elevation: 0,
              title: const Text(
                "Pizza Tracker",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
              ),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                  tooltip: "Alerts (soon)",
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    const NehBigCard(),
                    const SizedBox(height: 14),
                    const WidgetSetupCard(),
                    const SizedBox(height: 14),
                    const _MiniSection(
                      title: "Pizzerias (top)",
                      collection: "pizzerias",
                      emoji: "🍕",
                    ),
                    const SizedBox(height: 14),
                    const _MiniSection(
                      title: "Gay Bars (top)",
                      collection: "gayBars",
                      emoji: "🍸",
                    ),
                    const SizedBox(height: 26),
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

/// ============================================================
/// NEH BIG CARD (title from nehLabel)
/// ============================================================
class NehBigCard extends StatelessWidget {
  const NehBigCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection("app").doc("state").snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _Card(
            title: "Status",
            trailing: _Pill(
              text: "ERROR",
              bg: _UI.neonRed.withOpacity(0.10),
              border: _UI.neonRed.withOpacity(0.35),
              fg: _UI.neonRed,
            ),
            child: Text("ERROR: ${snap.error}",
                style: const TextStyle(color: _UI.neonRed, fontWeight: FontWeight.w700)),
          );
        }

        final data = snap.data?.data() ?? {};
        final neh = (data["nehPercent"] is num) ? (data["nehPercent"] as num).round() : 0;
        final nehLabel = (data["nehLabel"] ?? "NEH").toString();

        return _Card(
          title: nehLabel,
          trailing: _Pill(
            text: "LIVE",
            bg: _UI.neonRed.withOpacity(0.10),
            border: _UI.neonRed.withOpacity(0.35),
            fg: _UI.neonRed,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$neh",
                style: const TextStyle(fontSize: 62, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GaugeStrip(value: neh.clamp(0, 100).toDouble() / 100.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ============================================================
/// WIDGET SETUP CARD (real config + push to home widget)
/// ============================================================
enum _WidgetSource { neh, pizzerias, gayBars }

class WidgetSetupCard extends StatefulWidget {
  const WidgetSetupCard({super.key});

  @override
  State<WidgetSetupCard> createState() => _WidgetSetupCardState();
}

class _WidgetSetupCardState extends State<WidgetSetupCard> {
  static const String iOSWidgetName = "MyHomeWidget"; // change if your target name differs

  _WidgetSource _source = _WidgetSource.neh;
  String? _selectedDocId; // for pizzerias/gayBars
  String? _selectedName;
  double? _selectedDistance;
  int? _selectedMagnitude;
  String? _selectedStatus;

  bool _pushing = false;
  String? _lastPushMsg;

  Future<void> _pushToWidget({
    required String title,
    required String bigValue,
    required String subtitle,
    required String mode,
  }) async {
    setState(() {
      _pushing = true;
      _lastPushMsg = null;
    });

    try {
      final now = DateTime.now();
      await HomeWidget.saveWidgetData<String>("widget_mode", mode);
      await HomeWidget.saveWidgetData<String>("widget_title", title);
      await HomeWidget.saveWidgetData<String>("widget_value", bigValue);
      await HomeWidget.saveWidgetData<String>("widget_subtitle", subtitle);
      await HomeWidget.saveWidgetData<String>("widget_updated_at", now.toIso8601String());

      await HomeWidget.updateWidget(iOSName: iOSWidgetName);

      setState(() {
        _lastPushMsg = "Widget updated ✔";
      });
    } catch (e) {
      setState(() {
        _lastPushMsg = "Widget push failed: $e";
      });
    } finally {
      setState(() {
        _pushing = false;
      });
    }
  }

  Widget _sourceChip(String text, _WidgetSource v) {
    final selected = _source == v;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _source = v;
          _selectedDocId = null;
          _selectedName = null;
          _selectedDistance = null;
          _selectedMagnitude = null;
          _selectedStatus = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _UI.stroke.withOpacity(0.45) : _UI.panel2.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _UI.stroke.withOpacity(selected ? 1.0 : 0.75)),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: "Widget Setup",
      trailing: const Icon(Icons.widgets_outlined, color: Colors.white70, size: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pick what your Home Screen widget should show.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _sourceChip("NEH", _WidgetSource.neh),
              const SizedBox(width: 10),
              _sourceChip("Pizzerias", _WidgetSource.pizzerias),
              const SizedBox(width: 10),
              _sourceChip("Bars", _WidgetSource.gayBars),
            ],
          ),

          const SizedBox(height: 12),
          _buildPickerArea(),

          const SizedBox(height: 12),
          _buildPreview(),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pushing ? null : _onApplyPressed,
                  icon: _pushing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_outlined),
                  label: Text(_pushing ? "Applying…" : "Apply to Home Widget"),
                ),
              ),
            ],
          ),
          if (_lastPushMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastPushMsg!,
              style: TextStyle(
                color: _lastPushMsg!.contains("failed") ? _UI.neonRed : _UI.neonGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerArea() {
    if (_source == _WidgetSource.neh) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection("app").doc("state").snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final neh = (data["nehPercent"] is num) ? (data["nehPercent"] as num).round() : 0;
          final nehLabel = (data["nehLabel"] ?? "NEH").toString();

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _UI.panel2.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _UI.stroke.withOpacity(0.85)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nehLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "$neh",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 120, child: _GaugeStrip(value: neh.clamp(0, 100) / 100.0)),
              ],
            ),
          );
        },
      );
    }

    final collection = (_source == _WidgetSource.pizzerias) ? "pizzerias" : "gayBars";

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).limit(12).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text("ERROR: ${snap.error}", style: const TextStyle(color: _UI.neonRed));
        }
        if (!snap.hasData) {
          return const Text("Loading…", style: TextStyle(color: Colors.white70));
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text("No documents found.", style: TextStyle(color: Colors.white70));
        }

        return Container(
          decoration: BoxDecoration(
            color: _UI.panel2.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _UI.stroke.withOpacity(0.85)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < docs.length; i++) ...[
                _PickRow(
                  selected: _selectedDocId == docs[i].id,
                  doc: docs[i],
                  onTap: () {
                    final d = docs[i].data();
                    setState(() {
                      _selectedDocId = docs[i].id;
                      _selectedName = (d["name"] ?? docs[i].id).toString();
                      _selectedDistance = (d["distanceMi"] is num) ? (d["distanceMi"] as num).toDouble() : 0.0;
                      _selectedStatus = (d["status"] ?? "nominal").toString();
                      _selectedMagnitude = (d["magnitudePercent"] is num) ? (d["magnitudePercent"] as num).round() : 0;
                    });
                  },
                ),
                if (i != docs.length - 1) const Divider(height: 1, color: Color(0x221E2A44)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    // sexy / clean mini widget preview
    final title = (_source == _WidgetSource.neh)
        ? "NEH"
        : (_selectedName ?? "Pick a place");

    final bigValue = (_source == _WidgetSource.neh)
        ? "—"
        : ((_selectedMagnitude == null) ? "—" : "${_selectedMagnitude!}%");

    final subtitle = (_source == _WidgetSource.neh)
        ? "Global signal"
        : ((_selectedStatus == null) ? "Waiting selection" : "${_labelForStatus(_selectedStatus!)}");

    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _UI.stroke.withOpacity(0.95)),
        gradient: LinearGradient(
          colors: [
            _UI.panel2.withOpacity(0.95),
            _UI.panel.withOpacity(0.95),
            _UI.panel2.withOpacity(0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  bigValue,
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _UI.stroke.withOpacity(0.9)),
              color: _UI.panel2.withOpacity(0.75),
            ),
            alignment: Alignment.center,
            child: Icon(
              _source == _WidgetSource.neh
                  ? Icons.public_rounded
                  : (_source == _WidgetSource.pizzerias ? Icons.local_pizza_outlined : Icons.local_bar_outlined),
              size: 34,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onApplyPressed() async {
    // NEH -> reads from Firebase
    if (_source == _WidgetSource.neh) {
      final snap = await FirebaseFirestore.instance.collection("app").doc("state").get();
      final data = snap.data() ?? {};
      final neh = (data["nehPercent"] is num) ? (data["nehPercent"] as num).round() : 0;
      final nehLabel = (data["nehLabel"] ?? "NEH").toString();

      await _pushToWidget(
        title: nehLabel,
        bigValue: "$neh",
        subtitle: "Global signal",
        mode: "neh",
      );
      return;
    }

    // Place sources -> require selection
    if (_selectedDocId == null || _selectedName == null) {
      setState(() => _lastPushMsg = "Pick a place first.");
      return;
    }

    final isPizza = _source == _WidgetSource.pizzerias;
    final distance = (_selectedDistance ?? 0).toStringAsFixed(1);
    final mag = _selectedMagnitude ?? 0;
    final status = _selectedStatus ?? "nominal";

    await _pushToWidget(
      title: _selectedName!,
      bigValue: "$mag%",
      subtitle: "${isPizza ? "🍕" : "🍸"} $distance mi • ${_labelForStatus(status)}",
      mode: isPizza ? "pizzeria" : "gaybar",
    );
  }
}

class _PickRow extends StatelessWidget {
  final bool selected;
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onTap;

  const _PickRow({
    required this.selected,
    required this.doc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? {};
    final name = (d["name"] ?? doc.id).toString();
    final distanceMi = (d["distanceMi"] is num) ? (d["distanceMi"] as num).toDouble() : 0.0;
    final status = (d["status"] ?? "nominal").toString();
    final magnitude = (d["magnitudePercent"] is num) ? (d["magnitudePercent"] as num).round() : 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _UI.stroke.withOpacity(0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : Colors.white70),
              ),
            ),
            const SizedBox(width: 10),
            Text("${distanceMi.toStringAsFixed(1)} mi", style: const TextStyle(color: Colors.white60)),
            const SizedBox(width: 10),
            Text(
              "${_labelForStatus(status)} ($magnitude%)",
              style: TextStyle(
                color: _colorForStatus(status).withOpacity(0.95),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// MINI SECTIONS (top lists)
/// ============================================================
class _MiniSection extends StatelessWidget {
  final String title;
  final String collection;
  final String emoji;
  const _MiniSection({required this.title, required this.collection, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      trailing: Text(emoji, style: const TextStyle(fontSize: 18)),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(collection).limit(4).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Text("ERROR: ${snap.error}", style: const TextStyle(color: _UI.neonRed));
          if (!snap.hasData) return const Text("Loading…", style: TextStyle(color: Colors.white70));

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Text("No documents found.", style: TextStyle(color: Colors.white70));

          return Column(
            children: [
              for (int i = 0; i < docs.length; i++) ...[
                _MiniRow(doc: docs[i]),
                if (i != docs.length - 1) const Divider(height: 16, color: Color(0x221E2A44)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  const _MiniRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? {};
    final name = (d["name"] ?? doc.id).toString();
    final distanceMi = (d["distanceMi"] is num) ? (d["distanceMi"] as num).toDouble() : 0.0;
    final status = (d["status"] ?? "nominal").toString();
    final magnitude = (d["magnitudePercent"] is num) ? (d["magnitudePercent"] as num).round() : 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Text("${distanceMi.toStringAsFixed(1)} mi", style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 10),
        Text(
          "${_labelForStatus(status)} ($magnitude%)",
          style: TextStyle(color: _colorForStatus(status).withOpacity(0.95), fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// ============================================================
/// PLACES LIST PAGE
/// ============================================================
class PlacesListPage extends StatelessWidget {
  final String title;
  final String collection;
  final String leadingEmoji;
  final Color accent;
  final List<Color> borderGlow;

  const PlacesListPage({
    super.key,
    required this.title,
    required this.collection,
    required this.leadingEmoji,
    required this.accent,
    required this.borderGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 450)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: _UI.bg,
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded), tooltip: "Search (soon)"),
                const SizedBox(width: 6),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              sliver: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection(collection).limit(40).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return SliverToBoxAdapter(
                      child: _Card(
                        title: "Error",
                        child: Text("ERROR: ${snap.error}", style: const TextStyle(color: _UI.neonRed)),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text("Loading…", style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                    );
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _Card(
                        title: "Empty",
                        child: Text("No documents found.", style: TextStyle(color: Colors.white70)),
                      ),
                    );
                  }

                  return SliverList.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PlaceCard(
                          doc: docs[i],
                          leadingEmoji: leadingEmoji,
                          accent: accent,
                          glow: borderGlow,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// PLACE CARD
/// ============================================================
class PlaceCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final String leadingEmoji;
  final Color accent;
  final List<Color> glow;

  const PlaceCard({
    super.key,
    required this.doc,
    required this.leadingEmoji,
    required this.accent,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? {};
    final name = (d["name"] ?? doc.id).toString();
    final distanceMi = (d["distanceMi"] is num) ? (d["distanceMi"] as num).toDouble() : 0.0;
    final status = (d["status"] ?? "nominal").toString();
    final magnitude = (d["magnitudePercent"] is num) ? (d["magnitudePercent"] as num).round() : 0;

    final chart = _FakeChart.fromDoc(docId: doc.id, magnitude: magnitude, status: status);

    return _GlowCard(
      glow: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(leadingEmoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                text: _chipTextForStatus(status),
                bg: _colorForStatus(status).withOpacity(0.12),
                border: _colorForStatus(status).withOpacity(0.35),
                fg: _colorForStatus(status),
              ),
              const SizedBox(width: 10),
              _TinyIconButton(icon: Icons.close_rounded, onTap: () {}),
              const SizedBox(width: 8),
              _TinyIconButton(icon: Icons.local_taxi_outlined, onTap: () {}),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Text(
                "${distanceMi.toStringAsFixed(1)} mi",
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                "${_labelForStatus(status)} ($magnitude%)",
                style: TextStyle(
                  color: _colorForStatus(status).withOpacity(0.95),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0x221E2A44), height: 1),
          const SizedBox(height: 12),

          const Text(
            "POPULAR TIMES ANALYSIS",
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),

          _BarChart(
            values: chart.values,
            closedMask: chart.closedMask,
            accent: accent,
          ),
          const SizedBox(height: 8),
          const _TimeLabels(),
        ],
      ),
    );
  }
}

class _TimeLabels extends StatelessWidget {
  const _TimeLabels();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _TimeLabel("12p")),
        Expanded(child: _TimeLabel("3p")),
        Expanded(child: _TimeLabel("6p")),
        Expanded(child: _TimeLabel("9p")),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final String t;
  const _TimeLabel(this.t);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Text(t, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

/// ============================================================
/// WIDGET PAGE (shows live values + quick re-apply)
/// ============================================================
class WidgetPage extends StatelessWidget {
  const WidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Widget"),
        backgroundColor: _UI.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: const [
          _Card(
            title: "Tip",
            child: Text(
              "Use the Overview > Widget Setup.\nThat pushes the selected signal to your Home Screen widget.",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          SizedBox(height: 12),
          _Card(
            title: "Home Screen Widget",
            child: Text(
              "If widget doesn't refresh:\n- check App Groups on Runner + Widget target\n- confirm suiteName matches\n- run on real device",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// BAR CHART (deterministic random)
/// ============================================================
class _BarChart extends StatelessWidget {
  final List<double> values; // 0..1
  final List<bool> closedMask; // true => show as "closed" stub
  final Color accent;

  const _BarChart({
    required this.values,
    required this.closedMask,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    assert(values.length == closedMask.length);

    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Bar(
                  v: values[i],
                  closed: closedMask[i],
                  accent: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double v;
  final bool closed;
  final Color accent;

  const _Bar({required this.v, required this.closed, required this.accent});

  @override
  Widget build(BuildContext context) {
    final h = closed ? 0.08 : (0.10 + (v.clamp(0, 1) * 0.90));
    final color = closed ? Colors.white24 : accent;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        height: 110 * h,
        decoration: BoxDecoration(
          color: color.withOpacity(closed ? 0.55 : 0.95),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white.withOpacity(closed ? 0.12 : 0.10), width: 1),
          boxShadow: closed
              ? const []
              : [
                  BoxShadow(
                    color: accent.withOpacity(0.18),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
      ),
    );
  }
}

class _FakeChart {
  final List<double> values;
  final List<bool> closedMask;

  _FakeChart(this.values, this.closedMask);

  static _FakeChart fromDoc({
    required String docId,
    required int magnitude,
    required String status,
  }) {
    int seed = docId.hashCode ^ (magnitude * 997) ^ status.hashCode;
    final r = Random(seed);

    const n = 14;
    final values = List<double>.filled(n, 0.0);
    final closed = List<bool>.filled(n, false);

    final leftClosed = 1 + r.nextInt(2);
    final rightClosed = 1 + r.nextInt(3);
    for (int i = 0; i < leftClosed; i++) closed[i] = true;
    for (int i = n - rightClosed; i < n; i++) closed[i] = true;

    final peakPos = (3 + r.nextInt(n - 6)).toDouble();
    final peak = 0.55 + (r.nextDouble() * 0.40);
    for (int i = 0; i < n; i++) {
      if (closed[i]) {
        values[i] = 0.0;
        continue;
      }
      final x = (i - peakPos).abs();
      final base = (1.0 - (x / (n * 0.75))).clamp(0.08, 1.0);
      final noise = (r.nextDouble() - 0.5) * 0.18;
      var v = (base * peak) + noise;

      final magBoost = (magnitude.clamp(0, 300) / 300.0) * 0.28;
      if (status.toLowerCase().contains("spike")) v += 0.10 + magBoost;
      if (status.toLowerCase().contains("quieter")) v -= 0.08;

      values[i] = v.clamp(0.10, 1.0);
    }

    return _FakeChart(values, closed);
  }
}

/// ============================================================
/// UI PRIMITIVES
/// ============================================================
class _UI {
  static const bg = Color(0xFF070B14);
  static const panel = Color(0xFF0E1424);
  static const panel2 = Color(0xFF0B1020);
  static const stroke = Color(0xFF1E2A44);

  static const neonBlue = Color(0xFF2D6BFF);
  static const neonGreen = Color(0xFF2DFF8B);
  static const neonRed = Color(0xFFFF375F);
  static const neonPink = Color(0xFFFF4FD8);

  static const glowBlue = [Color(0xFF2D6BFF), Color(0xFF34D3FF), Color(0xFF2D6BFF)];
  static const glowPink = [Color(0xFF00E5FF), Color(0xFFFF4FD8), Color(0xFF7C4DFF)];
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _UI.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _UI.stroke.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _GlowCard extends StatelessWidget {
  final Widget child;
  final List<Color> glow;

  const _GlowCard({required this.child, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: glow),
      ),
      padding: const EdgeInsets.all(1.2),
      child: Container(
        decoration: BoxDecoration(
          color: _UI.panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _UI.stroke.withOpacity(0.85)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color fg;

  const _Pill({required this.text, required this.bg, required this.border, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 11),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _UI.panel2.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _UI.stroke.withOpacity(0.85)),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }
}

class _GaugeStrip extends StatelessWidget {
  final double value; // 0..1
  const _GaugeStrip({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: _UI.panel2,
          border: Border.all(color: _UI.stroke),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _UI.neonGreen.withOpacity(0.95),
                    _UI.neonBlue.withOpacity(0.95),
                    _UI.neonRed.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// STATUS HELPERS
/// ============================================================
String _chipTextForStatus(String status) {
  final s = status.toLowerCase();
  if (s.contains("closed")) return "closed";
  if (s.contains("spike")) return "spike";
  if (s.contains("quiet")) return "quieter";
  if (s.contains("nominal")) return "nominal";
  return status;
}

String _labelForStatus(String status) {
  final s = status.toLowerCase();
  if (s.contains("spike")) return "SPIKE";
  if (s.contains("quiet")) return "quieter";
  if (s.contains("closed")) return "CLOSED";
  if (s.contains("nominal")) return "Nominal";
  return status;
}

Color _colorForStatus(String status) {
  final s = status.toLowerCase();
  if (s.contains("spike")) return _UI.neonRed;
  if (s.contains("quiet")) return _UI.neonPink;
  if (s.contains("closed")) return Colors.white54;
  return _UI.neonGreen;
}
