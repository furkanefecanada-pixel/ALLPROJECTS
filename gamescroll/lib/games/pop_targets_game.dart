import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PopTargetsGame extends StatefulWidget {
  const PopTargetsGame({super.key});

  @override
  State<PopTargetsGame> createState() => _PopTargetsGameState();
}

class _PopTargetsGameState extends State<PopTargetsGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  Size _size = const Size(400, 800);
  bool _inited = false;

  final _rnd = Random();
  final List<_Target> targets = [];

  int score = 0;
  int hp = 3;
  int streak = 0;
  int bestStreak = 0;

  double timeAlive = 0;
  bool gameOver = false;

  double spawnT = 0;

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

  int _level() {
    final byScore = score ~/ 14;
    final byTime = (timeAlive ~/ 18).toInt();
    return 1 + max(byScore, byTime);
  }

  void _reset(Size s) {
    _size = s;
    _inited = true;

    targets.clear();
    score = 0;
    hp = 3;
    streak = 0;
    bestStreak = 0;
    timeAlive = 0;
    gameOver = false;
    spawnT = 0;
    _last = Duration.zero;
  }

  void _tapDown(TapDownDetails d) {
    final p = d.localPosition;
    if (gameOver) {
      _reset(_size);
      return;
    }

    // find nearest hit
    _Target? hit;
    for (final t in targets) {
      final dx = t.x - p.dx;
      final dy = t.y - p.dy;
      if (sqrt(dx * dx + dy * dy) <= t.r) {
        hit = t;
        break;
      }
    }

    if (hit != null) {
      targets.remove(hit);
      streak += 1;
      bestStreak = max(bestStreak, streak);

      // score: streak ile küçük bonus
      final add = 1 + (streak >= 5 ? 1 : 0) + (streak >= 10 ? 1 : 0);
      score += add;
    } else {
      // miss => streak reset (ceza az)
      streak = 0;
    }
  }

  void _update(double dt) {
    if (!_inited || gameOver) return;

    timeAlive += dt;
    final lvl = _level();

    // spawn interval shorter with level
    final spawnInterval = (0.82 - (lvl - 1) * 0.05).clamp(0.22, 0.82);
    spawnT += dt;
    if (spawnT >= spawnInterval) {
      spawnT = 0;
      targets.add(_spawnTarget(lvl));
    }

    // update targets lifetimes
    final dead = <_Target>[];
    for (final t in targets) {
      t.life -= dt;
      if (t.life <= 0) dead.add(t);
    }

    if (dead.isNotEmpty) {
      targets.removeWhere((e) => dead.contains(e));
      // expire => hp down per expired target
      hp -= dead.length;
      streak = 0;
      if (hp <= 0) {
        hp = 0;
        gameOver = true;
      }
    }

    if (targets.length > 18) targets.removeRange(0, targets.length - 18);
  }

  _Target _spawnTarget(int lvl) {
    final pad = 42.0;
    final x = pad + _rnd.nextDouble() * (_size.width - pad * 2);
    final y = _size.height * 0.28 + _rnd.nextDouble() * (_size.height * 0.42);

    // size + lifetime difficulty
    final r = (28.0 - (lvl - 1) * 1.2).clamp(14.0, 28.0) + _rnd.nextDouble() * 4;
    final life = (1.25 - (lvl - 1) * 0.06).clamp(0.45, 1.25) + _rnd.nextDouble() * 0.12;

    final isBomb = lvl >= 6 && _rnd.nextDouble() < 0.10;
    return _Target(x: x, y: y, r: r, life: life, maxLife: life, isBomb: isBomb);
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
          painter: _PopTargetsPainter(
            targets: targets,
            hp: hp,
            score: score,
            streak: streak,
            bestStreak: bestStreak,
            level: _level(),
            gameOver: gameOver,
            timeAlive: timeAlive,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

class _Target {
  double x, y, r;
  double life, maxLife;
  final bool isBomb;
  _Target({
    required this.x,
    required this.y,
    required this.r,
    required this.life,
    required this.maxLife,
    required this.isBomb,
  });
}

class _PopTargetsPainter extends CustomPainter {
  final List<_Target> targets;
  final int hp;
  final int score;
  final int streak;
  final int bestStreak;
  final int level;
  final bool gameOver;
  final double timeAlive;

  _PopTargetsPainter({
    required this.targets,
    required this.hp,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.level,
    required this.gameOver,
    required this.timeAlive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF0B1430), Color(0xFF060A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // dust
    final dot = Paint()..color = Colors.white.withOpacity(0.045);
    for (double y = 0; y < size.height; y += 28) {
      for (double x = 0; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }

    // targets
    for (final t in targets) {
      final p = Offset(t.x, t.y);
      final a = (t.life / t.maxLife).clamp(0.0, 1.0);

      final mainA = t.isBomb ? const Color(0xFFFF4D4D) : const Color(0xFF4CC9FF);
      final mainB = t.isBomb ? const Color(0xFFFF2D95) : const Color(0xFFFFB703);

      // glow
      canvas.drawCircle(
        p,
        t.r + 18,
        Paint()
          ..color = mainA.withOpacity(0.10 + (1 - a) * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );

      // fill
      canvas.drawCircle(
        p,
        t.r,
        Paint()
          ..shader = RadialGradient(
            colors: [mainA.withOpacity(0.95), mainB.withOpacity(0.75)],
          ).createShader(Rect.fromCircle(center: p, radius: t.r)),
      );

      // ring showing lifetime
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.22);
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: t.r + 10),
        -pi / 2,
        pi * 2 * a,
        false,
        ring,
      );

      // bomb icon
      if (t.isBomb) {
        final tp = TextPainter(
          text: TextSpan(
            text: "!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // hint
    if (!gameOver && timeAlive < 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: "Tap targets fast • Don’t let them fade",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.62),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset(20, size.height * 0.18));
    }

    if (!gameOver && streak >= 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: "STREAK x$streak",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4CC9FF).withOpacity(0.9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 16, size.height * 0.22));
    }

    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "GAME OVER\nScore: $score\nBest streak: $bestStreak\nLvl: $level\n\nTap to restart",
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

    // bottom HUD line
    final hud = TextPainter(
      text: TextSpan(
        text: "HP $hp   Score $score   Streak $streak   Lvl $level",
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.55),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    hud.paint(canvas, Offset(20, size.height - 32));
  }

  @override
  bool shouldRepaint(covariant _PopTargetsPainter oldDelegate) => true;
}
