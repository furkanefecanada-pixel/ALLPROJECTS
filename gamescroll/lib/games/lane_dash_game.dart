import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LaneDashGame extends StatefulWidget {
  const LaneDashGame({super.key});

  @override
  State<LaneDashGame> createState() => _LaneDashGameState();
}

class _LaneDashGameState extends State<LaneDashGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  Size _size = const Size(400, 800);
  bool _inited = false;

  int lane = 1; // 0..2
  int hp = 3;
  int score = 0;
  int bestCombo = 0;
  int combo = 0;

  double timeAlive = 0;
  bool gameOver = false;

  final _rnd = Random();
  final List<_Obstacle> obs = [];

  double spawnT = 0;
  double speed = 260; // increases

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = _dt(elapsed);
      _update(dt);
      setState(() {});
    })..start();
  }

  double _dt(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return 1 / 60.0;
    }
    final us = (elapsed - _last).inMicroseconds;
    _last = elapsed;
    final dt = us / 1e6;
    return dt.clamp(1 / 120.0, 1 / 20.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset(Size s) {
    _size = s;
    _inited = true;

    lane = 1;
    hp = 3;
    score = 0;
    combo = 0;
    bestCombo = 0;
    timeAlive = 0;
    gameOver = false;

    obs.clear();
    spawnT = 0;
    speed = 260;
    _last = Duration.zero;
  }

  int _level() {
    final byScore = score ~/ 12;
    final byTime = (timeAlive ~/ 15).toInt();
    return 1 + max(byScore, byTime);
  }

  void _tapDown(TapDownDetails d) {
    final x = d.localPosition.dx;
    if (gameOver) {
      _reset(_size);
      return;
    }
    if (x < _size.width / 2) {
      lane = max(0, lane - 1);
    } else {
      lane = min(2, lane + 1);
    }
  }

  void _update(double dt) {
    if (!_inited || gameOver) return;

    timeAlive += dt;
    final lvl = _level();

    // Difficulty curve
    speed = (260 + (lvl - 1) * 22).clamp(260, 520).toDouble();
    final spawnInterval = (0.78 - (lvl - 1) * 0.05).clamp(0.28, 0.78);

    spawnT += dt;
    if (spawnT >= spawnInterval) {
      spawnT = 0;
      obs.add(_spawnObstacle(lvl));
    }

    for (final o in obs) {
      o.y += speed * dt;
    }

    // Collision zone (player at bottom)
    final playerY = _size.height * 0.82;
    final hitZone = 26.0;

    // Check collisions + scoring when passed
    final dead = <_Obstacle>[];
    for (final o in obs) {
      if (!o.passed && o.y > playerY + 34) {
        o.passed = true;
        score += 1;
        combo += 1;
        bestCombo = max(bestCombo, combo);
      }

      if (o.lane == lane && (o.y - playerY).abs() < hitZone) {
        // hit
        dead.add(o);
        combo = 0;
        hp -= 1;
        if (hp <= 0) {
          hp = 0;
          gameOver = true;
          break;
        }
      }

      if (o.y > _size.height + 80) dead.add(o);
    }
    obs.removeWhere((e) => dead.contains(e));

    if (obs.length > 48) obs.removeRange(0, obs.length - 48);
  }

  _Obstacle _spawnObstacle(int lvl) {
    // Make it feel fair: avoid same lane streak too hard early
    int l = _rnd.nextInt(3);
    if (lvl <= 3 && obs.isNotEmpty && _rnd.nextDouble() < 0.55) {
      l = (obs.last.lane + 1 + _rnd.nextInt(2)) % 3;
    }
    final w = 44.0 + _rnd.nextDouble() * 20.0;
    final h = 22.0 + _rnd.nextDouble() * 18.0;
    final isGold = lvl >= 4 && _rnd.nextDouble() < 0.08; // bonus obstacle (optional)
    return _Obstacle(lane: l, y: -60, w: w, h: h, isGold: isGold);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = Size(c.maxWidth, c.maxHeight);
      if (!_inited) _reset(s);
      _size = s;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _tapDown,
        child: CustomPaint(
          painter: _LaneDashPainter(
            lane: lane,
            hp: hp,
            score: score,
            combo: combo,
            bestCombo: bestCombo,
            level: _level(),
            gameOver: gameOver,
            timeAlive: timeAlive,
            obs: obs,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

class _Obstacle {
  final int lane;
  double y;
  final double w;
  final double h;
  final bool isGold;
  bool passed = false;

  _Obstacle({
    required this.lane,
    required this.y,
    required this.w,
    required this.h,
    required this.isGold,
  });
}

class _LaneDashPainter extends CustomPainter {
  final int lane;
  final int hp;
  final int score;
  final int combo;
  final int bestCombo;
  final int level;
  final bool gameOver;
  final double timeAlive;
  final List<_Obstacle> obs;

  _LaneDashPainter({
    required this.lane,
    required this.hp,
    required this.score,
    required this.combo,
    required this.bestCombo,
    required this.level,
    required this.gameOver,
    required this.timeAlive,
    required this.obs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // BG
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF07162B), Color(0xFF060A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Lanes
    final laneW = size.width / 3;
    final grid = Paint()..color = Colors.white.withOpacity(0.06);
    for (int i = 1; i <= 2; i++) {
      canvas.drawRect(Rect.fromLTWH(laneW * i - 1, 0, 2, size.height), grid);
    }

    // Subtle dust
    final dot = Paint()..color = Colors.white.withOpacity(0.04);
    for (double y = 0; y < size.height; y += 28) {
      for (double x = 0; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }

    final playerY = size.height * 0.82;
    final playerX = laneW * (lane + 0.5);

    // Obstacles
    for (final o in obs) {
      final x = laneW * (o.lane + 0.5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, o.y), width: o.w, height: o.h),
        const Radius.circular(12),
      );

      final glowColor = o.isGold ? const Color(0xFFFFB703) : const Color(0xFFFF4D8D);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = glowColor.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              glowColor.withOpacity(0.85),
              const Color(0xFF4CC9FF).withOpacity(0.65),
            ],
          ).createShader(rect.outerRect),
      );
    }

    // Player (ship)
    canvas.drawCircle(
      Offset(playerX, playerY),
      28,
      Paint()
        ..color = const Color(0xFF00F5D4).withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(playerX, playerY), width: 56, height: 30),
        const Radius.circular(16),
      ),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF00F5D4), Color(0xFF00BBF9)])
            .createShader(Rect.fromLTWH(playerX - 28, playerY - 15, 56, 30)),
    );

    // HUD hint
    final hint = TextPainter(
      text: TextSpan(
        text: gameOver ? "Tap to restart" : "Tap LEFT/RIGHT to switch lanes",
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.58),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    hint.paint(canvas, Offset(20, size.height * 0.18));

    // Game over
    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "CRASHED\nScore: $score\nBest combo: $bestCombo\nLvl: $level",
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.12,
            color: Colors.white,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 60);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.36));
    }

    // Tiny footer (time)
    final tiny = TextPainter(
      text: TextSpan(
        text: "HP $hp   Score $score   Combo $combo   Lvl $level",
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.55),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    tiny.paint(canvas, Offset(20, size.height - 32));
  }

  @override
  bool shouldRepaint(covariant _LaneDashPainter oldDelegate) => true;
}
