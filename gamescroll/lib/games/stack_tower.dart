import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/math2d.dart';

class StackTowerGame extends StatefulWidget {
  const StackTowerGame({super.key});

  @override
  State<StackTowerGame> createState() => _StackTowerGameState();
}

class _StackTowerGameState extends State<StackTowerGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  final List<_Block> placed = [];
  _Block moving = _Block(x: 0.0, w: 180, y: 0);

  double dir = 1;
  double speed = 230;
  int score = 0;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final dt = 1 / 60.0;
      if (!gameOver) moving.x += dir * speed * dt;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _drop(Size size) {
    if (gameOver) {
      _reset(size);
      return;
    }

    final baseY = size.height * 0.72;
    const blockH = 20.0;

    if (placed.isEmpty) {
      placed.add(_Block(x: moving.x, w: moving.w, y: baseY));
      score = 1;
      _nextMoving(size, baseY - blockH);
      return;
    }

    final last = placed.last;
    final overlapL = max(moving.x, last.x);
    final overlapR = min(moving.x + moving.w, last.x + last.w);
    final overlapW = overlapR - overlapL;

    if (overlapW <= 18) {
      gameOver = true;
      return;
    }

    placed.add(_Block(x: overlapL, w: overlapW, y: last.y - blockH));
    score += 1;

    speed = clamp(speed + 18, 230, 560);
    _nextMoving(size, placed.last.y - blockH);
  }

  void _nextMoving(Size size, double y) {
    moving = _Block(x: 10, w: placed.last.w, y: y);
    dir = (Random().nextBool() ? 1 : -1);
  }

  void _reset(Size size) {
    placed.clear();
    score = 0;
    gameOver = false;
    speed = 230;
    moving = _Block(x: 10, w: 180, y: size.height * 0.72 - 20);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);

      if (!gameOver) {
        if (moving.x <= 0) dir = 1;
        if (moving.x + moving.w >= size.width) dir = -1;
      }

      return GestureDetector(
        onTap: () => _drop(size),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomPaint(
              painter: _StackPainter(placed: placed, moving: moving, gameOver: gameOver, score: score),
              child: const SizedBox.expand(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    _pill("Score", "$score"),
                    const Spacer(),
                    Text(
                      gameOver ? "Tap to restart" : "Tap to drop",
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _pill(String a, String b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F1A).withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text("$a: $b", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _Block {
  double x;
  double w;
  double y;
  _Block({required this.x, required this.w, required this.y});
}

class _StackPainter extends CustomPainter {
  final List<_Block> placed;
  final _Block moving;
  final bool gameOver;
  final int score;

  _StackPainter({required this.placed, required this.moving, required this.gameOver, required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF120A2A), Color(0xFF060A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // vignette
    final vignette = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 1.2,
        colors: [Color(0x2200FFFF), Color(0x00000000)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, vignette);

    const blockH = 20.0;
    final baseY = size.height * 0.72;

    // base line
    canvas.drawLine(
      Offset(0, baseY + blockH + 8),
      Offset(size.width, baseY + blockH + 8),
      Paint()..color = Colors.white.withOpacity(0.10)..strokeWidth = 2,
    );

    // placed blocks (color shifts)
    for (int i = 0; i < placed.length; i++) {
      final b = placed[i];
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(b.x, b.y, b.w, blockH),
        const Radius.circular(12),
      );

      final hue = (i * 22) % 360;
      final c1 = HSVColor.fromAHSV(1, hue.toDouble(), 0.75, 1).toColor();
      final c2 = HSVColor.fromAHSV(1, (hue + 30).toDouble(), 0.75, 1).toColor();

      final fill = Paint()
        ..shader = LinearGradient(colors: [c1.withOpacity(0.30), c2.withOpacity(0.18)]).createShader(r.outerRect);
      canvas.drawRRect(r, Paint()..color = const Color(0xFF0B0F1A).withOpacity(0.82));
      canvas.drawRRect(r, fill);

      if (i == placed.length - 1) {
        canvas.drawRRect(
          r,
          Paint()
            ..color = c1.withOpacity(0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }
    }

    // moving block
    final mr = RRect.fromRectAndRadius(
      Rect.fromLTWH(moving.x, moving.y, moving.w, blockH),
      const Radius.circular(12),
    );
    canvas.drawRRect(mr, Paint()..color = Colors.white.withOpacity(0.10));
    canvas.drawRRect(
      mr,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFF4D8D), Color(0xFFFFC857)])
            .createShader(mr.outerRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "GAME OVER\nScore: $score",
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1, color: Colors.white),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 60);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.38));
    }
  }

  @override
  bool shouldRepaint(covariant _StackPainter oldDelegate) => true;
}
