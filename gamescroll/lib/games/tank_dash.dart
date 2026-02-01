import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/math2d.dart';

class TankDashGame extends StatefulWidget {
  const TankDashGame({super.key});

  @override
  State<TankDashGame> createState() => _TankDashGameState();
}

class _TankDashGameState extends State<TankDashGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  Vec2 tankPos = Vec2(180, 520);
  Vec2 tankDir = Vec2(1, 0);
  Vec2 target = Vec2(180, 520);

  // Player tuning (daha “oynanır”)
  double tankSpeed = 190; // daha yavas
  double playerFireInterval = 0.32; // daha az spam
  int score = 0;
  int hp = 3;

  double timeAlive = 0;
  bool gameOver = false;

  final List<_Bullet> playerBullets = [];
  final List<_Bullet> enemyBullets = [];
  final List<_EnemyTank> enemies = [];

  double fireTimer = 0;
  double spawnTimer = 0;

  Size _lastSize = const Size(400, 800);
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = _computeDt(elapsed);
      _update(dt);
      setState(() {});
    })
      ..start();
  }

  double _computeDt(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return 1 / 60.0;
    }
    final us = (elapsed - _last).inMicroseconds;
    _last = elapsed;
    // dt'yi clamp'leyelim (bazı cihazlarda spike olabiliyor)
    final dt = us / 1e6;
    return dt.clamp(1 / 120.0, 1 / 20.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset(Size size) {
    _last = Duration.zero;
    _lastSize = size;

    tankPos = Vec2(size.width * 0.5, size.height * 0.62);
    target = tankPos.copy();
    tankDir = Vec2(1, 0);

    playerBullets.clear();
    enemyBullets.clear();
    enemies.clear();

    fireTimer = 0;
    spawnTimer = 0;

    score = 0;
    hp = 3;
    timeAlive = 0;
    gameOver = false;
  }

  int _level() {
    // hem score hem süreyle level artsın
    final byScore = score ~/ 10;
    final byTime = (timeAlive ~/ 18).toInt();
    return 1 + max(byScore, byTime);
  }

  double _spawnIntervalForLevel(int lvl) {
    // level arttıkça spawn daha sık
    // 1.10 -> 0.25’e kadar
    final v = 1.10 - (lvl - 1) * 0.08;
    return v.clamp(0.25, 1.10);
  }

  void _update(double dt) {
    if (gameOver) return;

    timeAlive += dt;
    final lvl = _level();

    // player move (follow target)
    final to = (target - tankPos);
    if (to.len > 4) {
      final d = to.normalized();
      tankDir = d;
      tankPos = tankPos + d * (tankSpeed * dt);
    }

    // clamp inside screen
    final size = _lastSize;
    tankPos.x = clamp(tankPos.x, 20, size.width - 20);
    tankPos.y = clamp(tankPos.y, 90, size.height - 90);

    // player autofire
    fireTimer += dt;
    if (fireTimer >= playerFireInterval) {
      fireTimer = 0;
      playerBullets.add(
        _Bullet(
          pos: tankPos + tankDir * 18,
          vel: tankDir * 520,
          r: 4.3,
          isEnemy: false,
          dmg: 1,
        ),
      );
    }

    // spawn enemies
    spawnTimer += dt;
    final spawnInterval = _spawnIntervalForLevel(lvl);
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0;
      enemies.add(_spawnEnemyTank(size, lvl));
    }

    // bullets update
    for (final b in playerBullets) {
      b.pos = b.pos + b.vel * dt;
    }
    for (final b in enemyBullets) {
      b.pos = b.pos + b.vel * dt;
    }

    // enemies update (move + shoot)
    for (final e in enemies) {
      e.aiT += dt;

      // takip yönü
      final toPlayer = (tankPos - e.pos);
      final dist = max(0.001, toPlayer.len);
      final dir = toPlayer * (1.0 / dist);

      // küçük “zigzag” hissi (çok az)
      final wobble = sin(e.aiT * 1.7 + e.seed) * 0.15;
      final perp = Vec2(-dir.y, dir.x);
      final moveDir = (dir + perp * wobble).normalized();

      e.dir = dir;

      // level arttıkça daha hızlı
      final moveSpeed = e.speed + (lvl - 1) * 9.0;
      e.pos = e.pos + moveDir * (moveSpeed * dt);

      // enemy fire (mesafeye göre)
      e.fireT += dt;
      final wantShoot = dist < e.fireRange;
      if (wantShoot && e.fireT >= e.fireCd) {
        e.fireT = 0;
        // level arttıkça daha sık ateş
        e.fireCd = (0.95 - (lvl - 1) * 0.06).clamp(0.35, 0.95);

        final v = 260.0 + (lvl - 1) * 18.0;
        enemyBullets.add(
          _Bullet(
            pos: e.pos + e.dir * 18,
            vel: e.dir * v,
            r: 3.7,
            isEnemy: true,
            dmg: 1,
          ),
        );
      }
    }

    // collisions: player bullets -> enemies
    final deadEnemies = <_EnemyTank>[];
    final spentPlayerBullets = <_Bullet>[];

    for (final e in enemies) {
      for (final b in playerBullets) {
        if ((e.pos - b.pos).len < e.r + b.r) {
          spentPlayerBullets.add(b);
          e.hp -= b.dmg;
          if (e.hp <= 0) {
            deadEnemies.add(e);
            score += 1;
          }
          break;
        }
      }
    }

    enemies.removeWhere((e) => deadEnemies.contains(e));
    playerBullets.removeWhere((b) => spentPlayerBullets.contains(b));

    // collisions: enemy bullets -> player
    final spentEnemyBullets = <_Bullet>[];
    for (final b in enemyBullets) {
      if ((tankPos - b.pos).len < 16 + b.r) {
        spentEnemyBullets.add(b);
        hp -= b.dmg;
        if (hp <= 0) {
          hp = 0;
          gameOver = true;
          break;
        }
      }
    }
    enemyBullets.removeWhere((b) => spentEnemyBullets.contains(b));

    // collisions: enemy tank body -> player (temas cezası)
    if (!gameOver) {
      final hit = enemies.where((e) => (e.pos - tankPos).len < e.r + 16).toList();
      if (hit.isNotEmpty) {
        // temas edeni sil, can kır
        for (final e in hit) {
          enemies.remove(e);
        }
        hp -= 1;
        if (hp <= 0) {
          hp = 0;
          gameOver = true;
        }
      }
    }

    // cleanup offscreen bullets
    playerBullets.removeWhere((b) =>
        b.pos.x < -60 ||
        b.pos.x > size.width + 60 ||
        b.pos.y < -80 ||
        b.pos.y > size.height + 80);

    enemyBullets.removeWhere((b) =>
        b.pos.x < -60 ||
        b.pos.x > size.width + 60 ||
        b.pos.y < -80 ||
        b.pos.y > size.height + 80);

    // cap counts
    if (enemies.length > 38) enemies.removeRange(0, enemies.length - 38);
    if (enemyBullets.length > 120) enemyBullets.removeRange(0, enemyBullets.length - 120);
    if (playerBullets.length > 90) playerBullets.removeRange(0, playerBullets.length - 90);
  }

  _EnemyTank _spawnEnemyTank(Size size, int lvl) {
    final side = _rnd.nextInt(4);
    final margin = 26.0;

    double x, y;
    switch (side) {
      case 0: // top
        x = _rnd.nextDouble() * size.width;
        y = -margin;
        break;
      case 1: // right
        x = size.width + margin;
        y = _rnd.nextDouble() * size.height;
        break;
      case 2: // bottom
        x = _rnd.nextDouble() * size.width;
        y = size.height + margin;
        break;
      default: // left
        x = -margin;
        y = _rnd.nextDouble() * size.height;
        break;
    }

    // level arttıkça düşman biraz daha tanklaşsın
    final baseHp = 1 + (lvl >= 4 ? 1 : 0) + (lvl >= 8 ? 1 : 0); // 1..3
    final r = 12.0 + min(7.0, (lvl - 1) * 0.5) + _rnd.nextDouble() * 2.0;
    final speed = 70.0 + _rnd.nextDouble() * 40.0;

    return _EnemyTank(
      pos: Vec2(x, y),
      r: r,
      speed: speed,
      hp: baseHp,
      fireRange: 420.0 + (lvl - 1) * 18.0,
      fireCd: (1.05 - (lvl - 1) * 0.06).clamp(0.35, 1.05),
      seed: _rnd.nextDouble() * 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      _lastSize = size;

      // ilk kez girince sıfırdan düzgün reset
      if (tankPos.x == 180 && tankPos.y == 520 && score == 0 && timeAlive == 0 && enemies.isEmpty) {
        _reset(size);
      }

      return GestureDetector(
        onPanDown: (d) => target = Vec2(d.localPosition.dx, d.localPosition.dy),
        onPanUpdate: (d) => target = Vec2(d.localPosition.dx, d.localPosition.dy),
        onTap: () {
          if (gameOver) _reset(size);
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomPaint(
              painter: _TankPainter(
                tankPos: tankPos,
                tankDir: tankDir,
                playerBullets: playerBullets,
                enemyBullets: enemyBullets,
                enemies: enemies,
                score: score,
                hp: hp,
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
                    _pill("Lvl", "${_level()}"),
                    const Spacer(),
                    Text(
                      gameOver ? "Tap to restart" : "Drag to move",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
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

class _Bullet {
  Vec2 pos;
  Vec2 vel;
  double r;
  final bool isEnemy;
  final int dmg;
  _Bullet({
    required this.pos,
    required this.vel,
    required this.r,
    required this.isEnemy,
    required this.dmg,
  });
}

class _EnemyTank {
  Vec2 pos;
  Vec2 dir = Vec2(1, 0);
  double r;
  double speed;

  int hp;

  double fireRange;
  double fireCd;
  double fireT = 0;

  double aiT = 0;
  final double seed;

  _EnemyTank({
    required this.pos,
    required this.r,
    required this.speed,
    required this.hp,
    required this.fireRange,
    required this.fireCd,
    required this.seed,
  });
}

class _TankPainter extends CustomPainter {
  final Vec2 tankPos;
  final Vec2 tankDir;

  final List<_Bullet> playerBullets;
  final List<_Bullet> enemyBullets;
  final List<_EnemyTank> enemies;

  final int score;
  final int hp;
  final int level;
  final bool gameOver;
  final double timeAlive;

  _TankPainter({
    required this.tankPos,
    required this.tankDir,
    required this.playerBullets,
    required this.enemyBullets,
    required this.enemies,
    required this.score,
    required this.hp,
    required this.level,
    required this.gameOver,
    required this.timeAlive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // background
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF07162B), Color(0xFF060A18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // subtle dust grid
    final dot = Paint()..color = Colors.white.withOpacity(0.045);
    for (double y = 0; y < size.height; y += 30) {
      for (double x = 0; x < size.width; x += 30) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }

    // enemy tanks
    for (final e in enemies) {
      _drawTank(
        canvas,
        pos: e.pos,
        dir: e.dir,
        bodyW: 44,
        bodyH: 28,
        glowA: const Color(0xFFFF4D4D),
        glowB: const Color(0xFFFF2D95),
        fillOpacity: 0.15,
        barrelColor: Colors.white.withOpacity(0.30),
      );

      // hp mini indicator (basit)
      final hpPaint = Paint()..color = Colors.white.withOpacity(0.22);
      final w = 26.0;
      final h = 4.0;
      final x = e.pos.x - w / 2;
      final y = e.pos.y + 22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(99)),
        hpPaint,
      );
      final fill = Paint()..color = const Color(0xFFFF4D4D).withOpacity(0.65);
      final f = (e.hp / 3.0).clamp(0.1, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w * f, h), const Radius.circular(99)),
        fill,
      );
    }

    // bullets
    final pBullet = Paint()..color = const Color(0xFF4CC9FF).withOpacity(0.88);
    for (final b in playerBullets) {
      canvas.drawCircle(Offset(b.pos.x, b.pos.y), b.r, pBullet);
    }

    final eBullet = Paint()..color = const Color(0xFFFFB000).withOpacity(0.88);
    for (final b in enemyBullets) {
      canvas.drawCircle(Offset(b.pos.x, b.pos.y), b.r, eBullet);
    }

    // player tank
    _drawTank(
      canvas,
      pos: tankPos,
      dir: tankDir,
      bodyW: 50,
      bodyH: 32,
      glowA: const Color(0xFF00F5D4),
      glowB: const Color(0xFF00BBF9),
      fillOpacity: 0.16,
      barrelColor: Colors.white.withOpacity(0.34),
    );

    // center hint
    if (!gameOver) {
      final hint = TextPainter(
        text: TextSpan(
          text: "Enemies are tanks now. They shoot back.\nSurvive longer → harder waves.",
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.52),
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      hint.paint(canvas, Offset((size.width - hint.width) / 2, size.height * 0.18));
    }

    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "TANK DOWN\nScore: $score\nLevel: $level\nTime: ${timeAlive.toStringAsFixed(1)}s",
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
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.36));
    }
  }

  void _drawTank(
    Canvas canvas, {
    required Vec2 pos,
    required Vec2 dir,
    required double bodyW,
    required double bodyH,
    required Color glowA,
    required Color glowB,
    required double fillOpacity,
    required Color barrelColor,
  }) {
    final angle = atan2(dir.y, dir.x);
    canvas.save();
    canvas.translate(pos.x, pos.y);
    canvas.rotate(angle);

    // glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: bodyW, height: bodyH),
        const Radius.circular(14),
      ),
      Paint()
        ..color = glowA.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // body gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: bodyW - 4, height: bodyH - 4),
        const Radius.circular(14),
      ),
      Paint()
        ..shader = LinearGradient(colors: [glowA, glowB])
            .createShader(Rect.fromLTWH(-bodyW / 2, -bodyH / 2, bodyW, bodyH))
        ..color = Colors.white.withOpacity(fillOpacity),
    );

    // barrel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bodyW * 0.14, -4, bodyW * 0.48, 8),
        const Radius.circular(6),
      ),
      Paint()..color = barrelColor,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TankPainter oldDelegate) => true;
}
