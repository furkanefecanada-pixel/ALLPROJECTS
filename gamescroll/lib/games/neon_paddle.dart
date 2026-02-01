import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/math2d.dart';

class NeonPaddleGame extends StatefulWidget {
  const NeonPaddleGame({super.key});

  @override
  State<NeonPaddleGame> createState() => _NeonPaddleGameState();
}

class _NeonPaddleGameState extends State<NeonPaddleGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  double paddleX = 0.5; // 0..1
  Vec2 ball = Vec2(200, 300);
  Vec2 vel = Vec2(220, -260);

  int score = 0;
  bool gameOver = false;

  Size _lastSize = const Size(400, 800);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final dt = 1 / 60.0;
      _update(dt);
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset() {
    score = 0;
    gameOver = false;
    ball = Vec2(_lastSize.width * 0.5, _lastSize.height * 0.55);
    vel = Vec2(220 * (Random().nextBool() ? 1 : -1), -260);
  }

  void _update(double dt) {
    if (gameOver) return;

    ball = ball + vel * dt;

    // walls
    if (ball.x < 16) {
      ball.x = 16;
      vel.x *= -1;
    }
    if (ball.x > _lastSize.width - 16) {
      ball.x = _lastSize.width - 16;
      vel.x *= -1;
    }
    if (ball.y < 80) {
      ball.y = 80;
      vel.y *= -1;
    }

    // paddle
    final paddleW = _lastSize.width * 0.32;
    final px = paddleX * _lastSize.width;
    final py = _lastSize.height * 0.78;

    final hit = (ball.y > py - 18 && ball.y < py + 10) && (ball.x > px - paddleW / 2 && ball.x < px + paddleW / 2);

    if (hit && vel.y > 0) {
      vel.y *= -1;
      // angle based on where it hits
      final dx = (ball.x - px) / (paddleW / 2);
      vel.x = clamp(vel.x + dx * 180, -520, 520);
      score += 1;

      // difficulty
      vel = vel * 1.02;
    }

    // lose
    if (ball.y > _lastSize.height + 30) {
      gameOver = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _lastSize = Size(c.maxWidth, c.maxHeight);
      if (ball.x == 200 && ball.y == 300) {
        ball = Vec2(_lastSize.width * 0.5, _lastSize.height * 0.55);
      }

      return GestureDetector(
        onPanDown: (d) => setState(() => paddleX = clamp(d.localPosition.dx / _lastSize.width, 0.08, 0.92)),
        onPanUpdate: (d) => setState(() => paddleX = clamp(d.localPosition.dx / _lastSize.width, 0.08, 0.92)),
        onTap: () {
          if (gameOver) _reset();
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomPaint(
              painter: _PaddlePainter(paddleX: paddleX, ball: ball, score: score, gameOver: gameOver),
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
                      gameOver ? "Tap to restart" : "Drag to move paddle",
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

class _PaddlePainter extends CustomPainter {
  final double paddleX;
  final Vec2 ball;
  final int score;
  final bool gameOver;

  _PaddlePainter({required this.paddleX, required this.ball, required this.score, required this.gameOver});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF120A2A), Color(0xFF060A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // glow dust
    final dot = Paint()..color = Colors.white.withOpacity(0.05);
    for (double y = 0; y < size.height; y += 28) {
      for (double x = 0; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }

    // paddle
    final paddleW = size.width * 0.32;
    final paddleH = 16.0;
    final px = paddleX * size.width;
    final py = size.height * 0.78;

    final pr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(px, py), width: paddleW, height: paddleH),
      const Radius.circular(999),
    );

    canvas.drawRRect(
      pr,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFB517FF), Color(0xFF00E5FF)])
            .createShader(pr.outerRect),
    );

    canvas.drawRRect(
      pr,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // ball
    canvas.drawCircle(
      Offset(ball.x, ball.y),
      10,
      Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      Offset(ball.x, ball.y),
      6.5,
      Paint()..color = Colors.white.withOpacity(0.92),
    );

    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "OUT\nScore: $score",
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1, color: Colors.white),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 60);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.38));
    }
  }

  @override
  bool shouldRepaint(covariant _PaddlePainter oldDelegate) => true;
}
