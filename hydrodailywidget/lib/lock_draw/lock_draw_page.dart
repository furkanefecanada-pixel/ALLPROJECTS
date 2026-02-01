import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
/// Same model as main.dart (or import)
class Friend {
  final String id;
  final String name;
  final String email;

  Friend({required this.id, required this.name, required this.email});

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }
}

/// Friend picker (unchanged UI)
class LockDrawFriendPicker extends StatelessWidget {
  final String userId;
  const LockDrawFriendPicker({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('users').doc(userId);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Choose a friend"),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() ?? {};
          final approvedRaw = (data['approved_friends'] as List<dynamic>? ?? []);
          final friends = approvedRaw
              .whereType<Map<String, dynamic>>()
              .map(Friend.fromMap)
              .where((f) => f.id.isNotEmpty)
              .toList();

          if (friends.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No friends yet.\nAdd a friend first from Profile > Invites.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final f = friends[i];
              return _Glass(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(
                    f.name.isEmpty ? "Friend" : f.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    f.email,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LockScreenDrawPage(
                          currentUserId: userId,
                          friend: f,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// --- Drawing data model ---
class _Line {
  final String id; // stroke doc id
  final String uid;
  final int color; // ARGB int
  final double width;
  final List<Offset> ptsNorm; // 0..1

  _Line({
    required this.id,
    required this.uid,
    required this.color,
    required this.width,
    required this.ptsNorm,
  });

  Map<String, dynamic> toStrokeJson() => {
        'uid': uid,
        'c': color,
        'w': width,
        'p': ptsNorm.map((o) => {'x': o.dx, 'y': o.dy}).toList(),
        't': DateTime.now().millisecondsSinceEpoch, // client time (fast ordering)
        'createdAt': FieldValue.serverTimestamp(), // optional (for audit)
      };

  static _Line fromStrokeDoc(String id, Map<String, dynamic> m) {
    final uid = (m['uid'] as String?) ?? '';
    final c = (m['c'] as num?)?.toInt() ?? 0xFFFFFF00;
    final w = (m['w'] as num?)?.toDouble() ?? 8.0;
    final p = (m['p'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => Offset(
              ((e['x'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
              ((e['y'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
            ))
        .toList();

    return _Line(id: id, uid: uid, color: c, width: w, ptsNorm: p);
  }
}

/// iOS lock-screen style draw (UI same, backend changed)
class LockScreenDrawPage extends StatefulWidget {
  final String currentUserId;
  final Friend friend;

  const LockScreenDrawPage({
    super.key,
    required this.currentUserId,
    required this.friend,
  });

  @override
  State<LockScreenDrawPage> createState() => _LockScreenDrawPageState();
}

class _LockScreenDrawPageState extends State<LockScreenDrawPage> {
  late final String _roomId;
  late final DocumentReference<Map<String, dynamic>> _roomRef;
  late final CollectionReference<Map<String, dynamic>> _strokesCol;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _strokesSub;

  // uid -> lines
  final Map<String, List<_Line>> _layers = {};
  final Set<String> _seenStrokeIds = {};

  // Canvas sizing
  Size _canvasSize = Size.zero;

  // Drawing state
  bool _drawing = false;
  String? _activeStrokeId;
  final List<Offset> _activePts = [];

  // Tools
  int _color = const Color(0xFFFFFF00).value;
  double _stroke = 10.0;

  // Clock
  Timer? _clock;
  DateTime _now = DateTime.now();

  // Painter tick
  final ValueNotifier<int> _paintTick = ValueNotifier<int>(0);

  // Error
  String _lastErr = '';

  // Room participants field type (list/map) backward compat
  dynamic _participantsField; // List<String> or Map<String,bool>

  // Reset (clears without deleting docs)
  int _resetT = 0; // client ms; query strokes where t > resetT

  List<String> get _participantsListSorted {
    final list = [widget.currentUserId, widget.friend.id]..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
debugPrint("AUTH=${FirebaseAuth.instance.currentUser?.uid} PAGE=${widget.currentUserId} FRIEND=${widget.friend.id}");
    _roomId = _makePairId(widget.currentUserId, widget.friend.id);
    _roomRef = FirebaseFirestore.instance.collection('lock_draws').doc(_roomId);
    _strokesCol = _roomRef.collection('strokes');

    Future.microtask(_initRoomAndListen);

    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _strokesSub?.cancel();
    _clock?.cancel();
    _paintTick.dispose();
    super.dispose();
  }

  static String _makePairId(String a, String b) {
    final list = [a, b]..sort();
    return "${list[0]}_${list[1]}";
  }

  Future<void> _initRoomAndListen() async {
  try {
    // ✅ always compute participants
    _participantsField = _participantsListSorted;

    // ✅ DO NOT _roomRef.get() before create
    // create/update in one shot
    await _roomRef.set({
      'participants': _participantsField,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'resetT': 0,
      'resetAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _lastErr = '';
    if (mounted) setState(() {});

    // listeners AFTER we ensured doc exists
    _listenRoom();
    _listenStrokes();
  } catch (e) {
    _lastErr = "$e";
    if (mounted) setState(() {});
  }
}


  void _listenRoom() {
    _roomSub?.cancel();
    _roomSub = _roomRef.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final newResetT = (data['resetT'] as num?)?.toInt() ?? 0;
      if (newResetT != _resetT) {
        _resetT = newResetT;

        // local clear (no delete)
        _layers.clear();
        _seenStrokeIds.clear();
        _paintTick.value++;

        // re-subscribe with new resetT filter
        _listenStrokes();
      }
    }, onError: (e) {
      _lastErr = "$e";
      if (mounted) setState(() {});
    });
  }

  void _listenStrokes() {
    _strokesSub?.cancel();

    // Query: only strokes after resetT, order by t (fast, no serverTimestamp wait)
    Query<Map<String, dynamic>> q = _strokesCol;
    if (_resetT > 0) {
      q = q.where('t', isGreaterThan: _resetT);
    }
    q = q.orderBy('t', descending: false).limitToLast(600);

    _strokesSub = q.snapshots().listen((qs) {
      for (final ch in qs.docChanges) {
        if (ch.type != DocumentChangeType.added) continue;

        final id = ch.doc.id;
        if (_seenStrokeIds.contains(id)) continue;

        final m = ch.doc.data();
        if (m == null) continue;

        final line = _Line.fromStrokeDoc(id, m);
        if (line.uid.isEmpty) continue;

        final list = _layers[line.uid] ?? <_Line>[];
        list.add(line);
        _layers[line.uid] = list;

        _seenStrokeIds.add(id);
      }
      _paintTick.value++;
    }, onError: (e) {
      _lastErr = "$e";
      if (mounted) setState(() {});
    });
  }

  Offset _toNorm(Offset local) {
    final w = _canvasSize.width <= 0 ? 1.0 : _canvasSize.width;
    final h = _canvasSize.height <= 0 ? 1.0 : _canvasSize.height;
    return Offset(
      (local.dx / w).clamp(0.0, 1.0),
      (local.dy / h).clamp(0.0, 1.0),
    );
  }

  // ─────────────────────────────────────────────
  // DRAW: Local preview instantly
  // SEND: Only when finger lifts (1 write)
  // ─────────────────────────────────────────────
  void _startLine(Offset localPos) {
    _drawing = true;

    // generate stroke doc id now (so we can mark seen & avoid duplicates)
    final strokeId = _strokesCol.doc().id;
    _activeStrokeId = strokeId;

    _activePts
      ..clear()
      ..add(_toNorm(localPos));

    // local preview line
    final uid = widget.currentUserId;
    final list = _layers[uid] ?? <_Line>[];
    list.add(_Line(
      id: strokeId,
      uid: uid,
      color: _color,
      width: _stroke,
      ptsNorm: List.of(_activePts),
    ));
    _layers[uid] = list;

    // mark as seen so listener won't duplicate later
    _seenStrokeIds.add(strokeId);

    _paintTick.value++;
  }

  void _addPoint(Offset localPos) {
    if (!_drawing) return;

    final p = _toNorm(localPos);

    // reduce jitter
    if (_activePts.isNotEmpty) {
      final prev = _activePts.last;
      final dx = (p.dx - prev.dx).abs();
      final dy = (p.dy - prev.dy).abs();
      if (dx < 0.002 && dy < 0.002) return;
    }

    _activePts.add(p);

    // update last local line preview
    final uid = widget.currentUserId;
    final list = _layers[uid];
    if (list != null && list.isNotEmpty) {
      final last = list.last;
      if (last.id == _activeStrokeId) {
        last.ptsNorm
          ..clear()
          ..addAll(_activePts);
      }
    }

    _paintTick.value++;
  }

  Future<void> _endLine() async {
    if (!_drawing) return;
    _drawing = false;

    final strokeId = _activeStrokeId;
    if (strokeId == null) return;

    // too short? (tap)
    if (_activePts.length < 2) {
      _activeStrokeId = null;
      _activePts.clear();
      return;
    }

    final uid = widget.currentUserId;

    // find local line to send (already in layers)
    final myList = _layers[uid] ?? <_Line>[];
    final line = myList.isNotEmpty ? myList.last : null;
    if (line == null || line.id != strokeId) {
      _activeStrokeId = null;
      _activePts.clear();
      return;
    }

    try {
      await _strokesCol.doc(strokeId).set(line.toStrokeJson());

      // optional: touch room updatedAt (small update, not required)
      await _roomRef.set({
        'participants': _participantsField,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastErr = '';
    } catch (e) {
      _lastErr = "$e";
      if (mounted) setState(() {});
    } finally {
      _activeStrokeId = null;
      _activePts.clear();
    }
  }

  // ─────────────────────────────────────────────
  // CLEAR (no delete): bump resetT
  // ─────────────────────────────────────────────
  Future<void> _clearMyLayer() async {
    // local clear my layer
    _layers[widget.currentUserId] = [];
    _paintTick.value++;

    // NOTE: This does not delete strokes. It's just local clear.
    // If you want "real clear", use _clearBoth (resetT).
  }

  Future<void> _clearBoth() async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _roomRef.set({
        'participants': _participantsField,
        'resetT': nowMs,
        'resetAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastErr = '';
    } catch (e) {
      _lastErr = "$e";
      if (mounted) setState(() {});
    }
  }

  String _timeText(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  String _dateText(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final wd = weekdays[(d.weekday - 1).clamp(0, 6)];
    final mo = months[(d.month - 1).clamp(0, 11)];
    return "$wd, $mo ${d.day}";
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.currentUserId;
    final otherUid = widget.friend.id;

    final myLines = _layers[myUid] ?? const <_Line>[];
    final otherLines = _layers[otherUid] ?? const <_Line>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, cons) {
            _canvasSize = Size(cons.maxWidth, cons.maxHeight);

            return Stack(
              children: [
                const _ModernPurpleWallpaper(),

                // Canvas
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _startLine(d.localPosition),
                    onPanUpdate: (d) => _addPoint(d.localPosition),
                    onPanEnd: (_) => _endLine(),
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _paintTick,
                        builder: (_, __, ___) {
                          return CustomPaint(
                            painter: _LockDrawPainter(
                              myLines: myLines,
                              otherLines: otherLines,
                              myAlpha: 1.0,
                              otherAlpha: 0.88,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ✅ iOS-like lockscreen text (NO rectangle)
                Positioned(
                  top: 18,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _dateText(_now),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              blurRadius: 16,
                              color: Colors.black.withOpacity(0.35),
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeText(_now),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 82,
                          height: 0.96,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -2.8,
                          shadows: [
                            Shadow(
                              blurRadius: 22,
                              color: Colors.black.withOpacity(0.45),
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _Pill(text: widget.friend.name.isEmpty ? "Friend" : widget.friend.name),
                          const _Pill(text: "Realtime"),
                        ],
                      ),
                      if (_lastErr.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            _lastErr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 11,
                              shadows: [
                                Shadow(
                                  blurRadius: 12,
                                  color: Colors.black.withOpacity(0.35),
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom toolbar (glass dock)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _ToolBar(
                    colorValue: _color,
                    stroke: _stroke,
                    onColor: (c) => setState(() => _color = c),
                    onStroke: (v) => setState(() => _stroke = v),
                    onClearMine: _clearMyLayer,
                    onClearBoth: _clearBoth,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// smoother painter
class _LockDrawPainter extends CustomPainter {
  final List<_Line> myLines;
  final List<_Line> otherLines;
  final double myAlpha;
  final double otherAlpha;

  _LockDrawPainter({
    required this.myLines,
    required this.otherLines,
    required this.myAlpha,
    required this.otherAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void drawOne(_Line line, double alpha) {
      final pts = line.ptsNorm;
      if (pts.length < 2) return;

      final paint = Paint()
        ..color = Color(line.color).withOpacity(alpha)
        ..strokeWidth = line.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final points = <Offset>[
        for (final p in pts) Offset(p.dx * size.width, p.dy * size.height),
      ];

      final path = Path()..moveTo(points.first.dx, points.first.dy);

      if (points.length == 2) {
        path.lineTo(points.last.dx, points.last.dy);
        canvas.drawPath(path, paint);
        return;
      }

      for (int i = 1; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);

      canvas.drawPath(path, paint);
    }

    for (final l in otherLines) {
      drawOne(l, otherAlpha);
    }
    for (final l in myLines) {
      drawOne(l, myAlpha);
    }
  }

  @override
  bool shouldRepaint(covariant _LockDrawPainter oldDelegate) => true;
}

/// Modern purple wallpaper similar vibe
class _ModernPurpleWallpaper extends StatelessWidget {
  const _ModernPurpleWallpaper();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7C3AED),
                  Color(0xFF6D28D9),
                  Color(0xFFDB2777),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, -0.2),
                  radius: 1.2,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  const _Glass({
    required this.child,
    required this.radius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  final int colorValue;
  final double stroke;
  final ValueChanged<int> onColor;
  final ValueChanged<double> onStroke;
  final Future<void> Function() onClearMine;
  final Future<void> Function() onClearBoth;
  final VoidCallback onBack;

  const _ToolBar({
    required this.colorValue,
    required this.stroke,
    required this.onColor,
    required this.onStroke,
    required this.onClearMine,
    required this.onClearBoth,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = <int>[
      const Color(0xFFFFFF00).value,
      const Color(0xFFFF4D4D).value,
      const Color(0xFF00E5FF).value,
      const Color(0xFFFFFFFF).value,
      const Color(0xFF00FF85).value,
    ];

    return _Glass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in colors)
                      _ColorDot(
                        color: Color(c),
                        selected: c == colorValue,
                        onTap: () => onColor(c),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                onSelected: (v) async {
                  if (v == 'mine') await onClearMine();
                  if (v == 'both') await onClearBoth();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'mine', child: Text("Clear my drawing")),
                  PopupMenuItem(value: 'both', child: Text("Clear both")),
                ],
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.brush, color: Colors.white70, size: 18),
              Expanded(
                child: Slider(
                  value: stroke.clamp(3, 24),
                  min: 3,
                  max: 24,
                  onChanged: onStroke,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "${stroke.round()}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? Colors.white : Colors.white.withOpacity(0.32);
    final scale = selected ? 1.12 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        transform: Matrix4.identity()..scale(scale, scale),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: selected ? 2.2 : 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
      ),
    );
  }
}
