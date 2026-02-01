import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/math2d.dart';

class PerfectTimingBarGame extends StatefulWidget {
  const PerfectTimingBarGame({super.key});

  @override
  State<PerfectTimingBarGame> createState() => _PerfectTimingBarGameState();
}

class _PerfectTimingBarGameState extends State<PerfectTimingBarGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  // World
  Size _size = const Size(400, 800);
  bool _inited = false;

  // Player (launcher)
  Vec2 playerPos = Vec2(200, 720);
  double aimX01 = 0.5; // 0..1, drag ile kontrol
  double fireCd = 0; // cooldown

  // Game state
  int score = 0;
  int hp = 3;
  int combo = 0;
  double timeAlive = 0;
  bool gameOver = false;

  // Difficulty
  double spawnT = 0;
  double spawnInterval = 1.05; // başta yavaş
  double baseBallSpeed = 95; // başta yavaş

  final Random _rnd = Random();

  final List<_Arrow> arrows = [];
  final List<_Ball> balls = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = _dt(elapsed);
      _update(dt);
      setState(() {});
    })
      ..start();
  }

  double _dt(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return 1 / 60.0;
    }
    final us = (elapsed - _last).inMicroseconds;
    _last = elapsed;
    // spike olursa oyun "zıplamasın"
    final dt = us / 1e6;
    return dt.clamp(1 / 120.0, 1 / 20.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int _level() {
    final byScore = score ~/ 12;
    final byTime = (timeAlive ~/ 18).toInt();
    return 1 + max(byScore, byTime);
  }

  void _reset(Size size) {
    _last = Duration.zero;
    _size = size;
    _inited = true;

    playerPos = Vec2(size.width * 0.5, size.height * 0.82);
    aimX01 = 0.5;

    arrows.clear();
    balls.clear();

    score = 0;
    hp = 3;
    combo = 0;
    timeAlive = 0;
    gameOver = false;

    spawnT = 0;
    spawnInterval = 1.05;
    baseBallSpeed = 95;
    fireCd = 0;
  }

  void _onDrag(Offset local) {
    final x = local.dx;
    aimX01 = ((x / _size.width)).clamp(0.0, 1.0);
  }

  void _shoot() {
    if (gameOver) return;
    if (fireCd > 0) return;

    // Aim: -60..+60 derece
    final center = 0.5;
    final dx = (aimX01 - center);
    final angle = dx * (pi / 3); // +/-60deg

    final dir = Vec2(sin(angle), -cos(angle)); // yukarı doğru
    final speed = (620.0 + min(120.0, combo * 10.0)); // combo ile az hız bonus
    final start = Vec2(playerPos.x, playerPos.y - 18);

    arrows.add(
      _Arrow(
        pos: start,
        vel: dir * speed,
        r: 5.2,
      ),
    );

    // cooldown: combo ile biraz düşsün (hızlı ama kontrol edilebilir)
    final base = 0.26;
    final cd = (base - min(0.10, combo * 0.01)).clamp(0.13, 0.26);
    fireCd = cd;
  }

  void _update(double dt) {
    if (!_inited) return;
    if (gameOver) return;

    timeAlive += dt;

    final lvl = _level();

    // Difficulty curve (yumuşak)
    spawnInterval = (1.05 - (lvl - 1) * 0.06).clamp(0.32, 1.05);
    baseBallSpeed = (95 + (lvl - 1) * 7.5).clamp(95, 190);

    // Cooldowns
    if (fireCd > 0) fireCd -= dt;

    // Spawn balls
    spawnT += dt;
    if (spawnT >= spawnInterval) {
      spawnT = 0;
      balls.add(_spawnBall(lvl));
    }

    // Update arrows
    for (final a in arrows) {
      a.t += dt;
      a.pos = a.pos + a.vel * dt;
    }

    // Update balls (rise up)
    for (final b in balls) {
      b.t += dt;
      // küçük yatay drift
      final drift = sin(b.t * 1.8 + b.seed) * 18.0;
      b.pos = b.pos + Vec2(drift, -b.speed) * dt;
    }

    // Collisions: arrow hits ball
    final deadArrows = <_Arrow>[];
    final deadBalls = <_Ball>[];

    for (final b in balls) {
      for (final a in arrows) {
        if ((b.pos - a.pos).len < (b.r + a.r)) {
          deadArrows.add(a);
          b.hp -= 1;

          if (b.hp <= 0) {
            deadBalls.add(b);
            score += 1 + (combo >= 4 ? 1 : 0); // küçük bonus
            combo += 1;
          } else {
            // vurduk ama patlamadı -> yine de combo artsın az
            combo += 1;
          }
          b.hitFlash = 0.18;
          break;
        }
      }
    }

    arrows.removeWhere((a) => deadArrows.contains(a));
    balls.removeWhere((b) => deadBalls.contains(b));

    // Arrow cleanup offscreen
    final before = arrows.length;
    arrows.removeWhere((a) =>
        a.pos.x < -60 ||
        a.pos.x > _size.width + 60 ||
        a.pos.y < -120 ||
        a.pos.y > _size.height + 120);

    // Eğer ok “boşa gitti” combo kırılmasın diye yumuşak: sadece uzun süre vuramazsan kır
    if (before != arrows.length) {
      // Ok çıktı ama vurmadıysa küçük combo decay
      if (combo > 0) combo = max(0, combo - 1);
    }

    // Ball reaches top => lose HP
    final escaped = <_Ball>[];
    for (final b in balls) {
      if (b.pos.y + b.r < 40) escaped.add(b);
    }
    if (escaped.isNotEmpty) {
      balls.removeWhere((b) => escaped.contains(b));
      hp -= escaped.length;
      combo = 0;
      if (hp <= 0) {
        hp = 0;
        gameOver = true;
      }
    }

    // Hit flash timer
    for (final b in balls) {
      if (b.hitFlash > 0) b.hitFlash -= dt;
    }

    // Caps
    if (balls.length > 28) balls.removeRange(0, balls.length - 28);
    if (arrows.length > 18) arrows.removeRange(0, arrows.length - 18);
  }

  _Ball _spawnBall(int lvl) {
    // Spawn near bottom, random x
    final x = 18 + _rnd.nextDouble() * (_size.width - 36);
    final y = _size.height + 30 + _rnd.nextDouble() * 40;

    // Ball size + hp based on level
    final r = 16.0 + _rnd.nextDouble() * 10.0;
    final fast = 0.85 + _rnd.nextDouble() * 0.45;
    final speed = baseBallSpeed * fast;

    // lvl ilerledikçe 2-3 hp chance
    int hp;
    final roll = _rnd.nextDouble();
    if (lvl >= 8 && roll < 0.22) {
      hp = 3;
    } else if (lvl >= 4 && roll < 0.28) {
      hp = 2;
    } else {
      hp = 1;
    }

    return _Ball(
      pos: Vec2(x, y),
      r: r,
      speed: speed,
      hp: hp,
      seed: _rnd.nextDouble() * 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      _size = size;

      if (!_inited) {
        _reset(size);
      }

      return GestureDetector(
        onPanDown: (d) => _onDrag(d.localPosition),
        onPanUpdate: (d) => _onDrag(d.localPosition),
        onTap: () {
          if (gameOver) {
            _reset(size);
          } else {
            _shoot();
          }
        },
        onDoubleTap: () => _reset(size),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomPaint(
              painter: _ArrowPopPainter(
                size: size,
                playerPos: playerPos,
                aimX01: aimX01,
                arrows: arrows,
                balls: balls,
                score: score,
                hp: hp,
                combo: combo,
                level: _level(),
                gameOver: gameOver,
                timeAlive: timeAlive,
              ),
              child: const SizedBox.expand(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    _pill("Score", "$score"),
                    const SizedBox(width: 10),
                    _pill("HP", "❤ x$hp"),
                    const SizedBox(width: 10),
                    _pill("Combo", "$combo"),
                    const SizedBox(width: 10),
                    _pill("Lvl", "${_level()}"),
                    const Spacer(),
                    Text(
                      gameOver ? "Tap = restart" : "Drag aim • Tap shoot",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.58),
                        fontWeight: FontWeight.w700,
                      ),
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
      child: Text(
        "$a: $b",
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}

class _Arrow {
  Vec2 pos;
  Vec2 vel;
  double r;
  double t = 0;
  _Arrow({required this.pos, required this.vel, required this.r});
}

class _Ball {
  Vec2 pos;
  double r;
  double speed;
  int hp;
  final double seed;
  double t = 0;
  double hitFlash = 0;

  _Ball({
    required this.pos,
    required this.r,
    required this.speed,
    required this.hp,
    required this.seed,
  });
}

class _ArrowPopPainter extends CustomPainter {
  final Size size;
  final Vec2 playerPos;
  final double aimX01;
  final List<_Arrow> arrows;
  final List<_Ball> balls;

  final int score;
  final int hp;
  final int combo;
  final int level;
  final bool gameOver;
  final double timeAlive;

  _ArrowPopPainter({
    required this.size,
    required this.playerPos,
    required this.aimX01,
    required this.arrows,
    required this.balls,
    required this.score,
    required this.hp,
    required this.combo,
    required this.level,
    required this.gameOver,
    required this.timeAlive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF07162B), Color(0xFF060A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // subtle dust
    final dot = Paint()..color = Colors.white.withOpacity(0.045);
    for (double y = 0; y < size.height; y += 28) {
      for (double x = 0; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }

    // Top danger line
    canvas.drawRect(
      Rect.fromLTWH(0, 46, size.width, 2),
      Paint()..color = const Color(0xFFFF4D4D).withOpacity(0.22),
    );

    // Aim guide
    final cx = size.width * aimX01;
    final dx = (aimX01 - 0.5);
    final ang = dx * (pi / 3);
    final dir = Offset(sin(ang), -cos(ang));

    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(playerPos.x, playerPos.y - 8),
      Offset(playerPos.x, playerPos.y - 8) + dir * 160,
      guidePaint,
    );

    // Player launcher (neon)
    _drawLauncher(canvas, Offset(playerPos.x, playerPos.y), dir);

    // Balls
    for (final b in balls) {
      final center = Offset(b.pos.x, b.pos.y);

      final glow = Paint()
        ..color = const Color(0xFF7C5CFF).withOpacity(0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, b.r + 14, glow);

      // hit flash
      final flash = b.hitFlash > 0 ? (b.hitFlash / 0.18).clamp(0.0, 1.0) : 0.0;

      final ballPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0xFF4CC9FF), Colors.white, 0.18 + 0.35 * flash)!,
            const Color(0xFF7C5CFF),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: b.r));

      canvas.drawCircle(center, b.r, ballPaint);

      // hp ring
      if (b.hp >= 2) {
        final ring = Paint()
          ..color = Colors.white.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, b.r + 4, ring);

        final tp = TextPainter(
          text: TextSpan(
            text: "${b.hp}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Arrows
    for (final a in arrows) {
      final p = Offset(a.pos.x, a.pos.y);

      // trail
      final trail = Paint()
        ..color = const Color(0xFF00F5D4).withOpacity(0.12)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p, p - Offset(a.vel.x, a.vel.y).scale(0.02, 0.02), trail);

      final glow = Paint()
        ..color = const Color(0xFF00F5D4).withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(p, a.r + 10, glow);

      final head = Paint()..color = const Color(0xFF00F5D4).withOpacity(0.92);
      canvas.drawCircle(p, a.r, head);
    }

    // Center hint (first seconds)
    if (!gameOver && timeAlive < 6) {
      final hint = TextPainter(
        text: TextSpan(
          text: "Drag to aim • Tap to shoot\nDon't let balls pass the red line",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.62),
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      hint.paint(canvas, Offset((size.width - hint.width) / 2, size.height * 0.18));
    }

    // Combo feedback
    if (!gameOver && combo >= 4) {
      final tp = TextPainter(
        text: TextSpan(
          text: "COMBO x$combo",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4CC9FF).withOpacity(0.88),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 16, size.height * 0.22));
    }

    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "GAME OVER\nScore: $score\nLevel: $level\nTime: ${timeAlive.toStringAsFixed(1)}s\n\nTap to restart",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.12,
            color: Colors.white,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 60);

      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.34));
    }
  }

  void _drawLauncher(Canvas canvas, Offset pos, Offset dir) {
    // base glow
    canvas.drawCircle(
      pos,
      28,
      Paint()
        ..color = const Color(0xFF00BBF9).withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // base body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 64, height: 34),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.white.withOpacity(0.10),
    );

    // barrel
    final barrelStart = pos + const Offset(0, -6);
    final barrelEnd = barrelStart + dir * 30;

    final barrel = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00F5D4), Color(0xFF00BBF9)],
      ).createShader(Rect.fromPoints(barrelStart, barrelEnd))
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(barrelStart, barrelEnd, barrel);

    // aim dot
    canvas.drawCircle(
      barrelEnd,
      5,
      Paint()..color = Colors.white.withOpacity(0.52),
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPopPainter oldDelegate) => true;
}
