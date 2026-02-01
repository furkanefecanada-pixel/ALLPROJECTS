import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoulettePhoto {
  final String id;
  final String url;
  final int weight;
  final bool enabled;

  RoulettePhoto({
    required this.id,
    required this.url,
    required this.weight,
    required this.enabled,
  });

  factory RoulettePhoto.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RoulettePhoto(
      id: doc.id,
      url: (d['url'] ?? '').toString(),
      weight: (d['weight'] ?? 1) is int ? (d['weight'] ?? 1) : (d['weight'] as num).toInt(),
      enabled: (d['enabled'] ?? true) == true,
    );
  }
}

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _selectedUrl;

  late final AnimationController _ctrl;
  double _wheelTurns = 0; // total turns to animate (can be > 1)
  double _currentAngle = 0; // for painter highlight

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addListener(() {
        // map controller value (0..1) to angle
        final eased = Curves.easeOutCubic.transform(_ctrl.value);
        final angle = 2 * pi * _wheelTurns * eased;
        setState(() => _currentAngle = angle);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<List<RoulettePhoto>> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('roulette_photos')
        .where('enabled', isEqualTo: true)
        .get();

    final list = snap.docs.map((d) => RoulettePhoto.fromDoc(d)).toList();
    return list.where((e) => e.url.trim().isNotEmpty).toList();
  }

  RoulettePhoto _pickWeighted(List<RoulettePhoto> items) {
    final rnd = Random();
    final total = items.fold<int>(0, (s, e) => s + max(0, e.weight));
    if (total <= 0) return items[rnd.nextInt(items.length)];
    int r = rnd.nextInt(total);
    for (final it in items) {
      r -= max(0, it.weight);
      if (r < 0) return it;
    }
    return items.last;
  }

  Future<void> _spin() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final items = await _fetch();

      if (!mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photos found. Add url in Firestore.')),
        );
        return;
      }

      final picked = _pickWeighted(items);

      // Spin animation: random extra turns + random offset
      final rnd = Random();
      final extraTurns = 4 + rnd.nextInt(3); // 4..6 turns
      final offset = rnd.nextDouble(); // 0..1 turn

      _wheelTurns = extraTurns + offset;

      _ctrl.reset();
      await _ctrl.forward();

      if (!mounted) return;

      setState(() => _selectedUrl = picked.url);

      // Show result modal (professional)
      await _showResultSheet(picked.url);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResultSheet(String url) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121216),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(blurRadius: 28, offset: Offset(0, 16), color: Colors.black54),
              ],
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.favorite_rounded, color: Color(0xFFFF5A7A)),
                    SizedBox(width: 8),
                    Text(
                      'Your Pick',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, w, p) {
                        if (p == null) return w;
                        return Container(
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Text('Image failed to load', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A7A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _spin();
                        },
                        child: const Text('Spin Again'),
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
  }

  @override
  Widget build(BuildContext context) {
    final bg = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B0B10), Color(0xFF161627), Color(0xFF0B0B10)],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Roulette', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bg),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                _TopCard(selectedUrl: _selectedUrl),
                const SizedBox(height: 18),

                // Wheel
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // glow ring
                        Container(
                          width: 310,
                          height: 310,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(blurRadius: 40, color: Color(0x33FF5A7A)),
                            ],
                          ),
                        ),

                        // wheel + rotation
                        Transform.rotate(
                          angle: _currentAngle,
                          child: CustomPaint(
                            size: const Size(300, 300),
                            painter: _RouletteWheelPainter(),
                          ),
                        ),

                        // center cap
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF121216),
                            border: Border.all(color: Colors.white12),
                            boxShadow: const [
                              BoxShadow(blurRadius: 16, offset: Offset(0, 10), color: Colors.black45),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.favorite_rounded, color: Color(0xFFFF5A7A), size: 32),
                          ),
                        ),

                        // pointer
                        Positioned(
                          top: 2,
                          child: CustomPaint(
                            size: const Size(44, 44),
                            painter: _PointerPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _loading ? null : _spin,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loading) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Text('Spinning...'),
                        ] else ...[
                          const Icon(Icons.casino_rounded),
                          const SizedBox(width: 8),
                          const Text('SPIN', style: TextStyle(fontWeight: FontWeight.w800)),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Relationship roulette • Tap SPIN and enjoy the surprise',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  final String? selectedUrl;
  const _TopCard({required this.selectedUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white10,
            ),
            child: const Icon(Icons.photo_library_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo Roulette',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedUrl == null ? 'Press SPIN to choose a photo' : 'Last pick is ready ✅',
                  style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (selectedUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.network(
                  selectedUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouletteWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = min(size.width, size.height) / 2;

    // outer ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = const Color(0x22FFFFFF);

    canvas.drawCircle(c, r - 4, ringPaint);

    // wheel background
    final bg = Paint()..color = const Color(0xFF10101A);
    canvas.drawCircle(c, r - 10, bg);

    // segments
    const segments = 12;
    final segRect = Rect.fromCircle(center: c, radius: r - 14);

    for (int i = 0; i < segments; i++) {
      final start = (2 * pi / segments) * i;
      final sweep = (2 * pi / segments);

      final isAlt = i.isEven;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isAlt ? const Color(0xFF1B1B2B) : const Color(0xFF141424);

      canvas.drawArc(segRect, start, sweep, true, paint);

      // divider line
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.06);
      canvas.drawArc(segRect, start, 0.001, true, linePaint);
    }

    // inner ring
    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(c, r * 0.62, innerRing);

    // subtle highlight
    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.10), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r - 14, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.72)
      ..quadraticBezierTo(w / 2, h, 0, h * 0.72)
      ..close();

    final fill = Paint()..color = const Color(0xFFFF5A7A);
    final shadow = Paint()..color = Colors.black.withOpacity(0.35);

    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadow);
    canvas.restore();

    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.18);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
