import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// MouseSlither Lite
/// - Self-collision yok (kendi kuyruğuna çarpsan ölmezsin)
/// - Daha yavaş ve daha basit
/// - dt bazlı (120Hz cihazda hızlanmaz)

class OrbRunnerGame extends StatefulWidget {
  const OrbRunnerGame({super.key});

  @override
  State<OrbRunnerGame> createState() => _OrbRunnerGameState();
}

class _OrbRunnerGameState extends State<OrbRunnerGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final rnd = Random();

  // World
  static const double worldW = 3200;
  static const double worldH = 3200;

  // Entities
  late _Snake player;
  final List<_Snake> bots = [];
  final List<_Pellet> pellets = [];
  final List<_FxDot> fx = [];

  // Camera
  Offset cam = const Offset(worldW / 2, worldH / 2);
  Size screen = const Size(400, 800);

  // Input
  Offset? targetWorld;

  // Game
  bool gameOver = false;
  int bestLen = 0;

  // Timing
  Duration? _last;

  @override
  void initState() {
    super.initState();
    _newGame();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _newGame() {
    gameOver = false;
    pellets.clear();
    bots.clear();
    fx.clear();

    player = _Snake.player(
      pos: Offset(worldW * 0.5, worldH * 0.5),
      hue: 330 / 360,
    );

    // Less clutter = simpler feel
    for (int i = 0; i < 420; i++) {
      pellets.add(_Pellet.random(rnd));
    }

    // Fewer bots
    for (int i = 0; i < 4; i++) {
      bots.add(
        _Snake.bot(
          pos: Offset(rnd.nextDouble() * worldW, rnd.nextDouble() * worldH),
          hue: (i * 0.18) % 1.0,
        ),
      );
    }

    cam = player.head;
    targetWorld = null;
  }

  void _tick(Duration now) {
    final prev = _last ?? now;
    _last = now;

    // dt seconds
    var dt = (now - prev).inMicroseconds / 1e6;
    // clamp: background/lag spike olunca roketlemesin
    dt = dt.clamp(0.0, 1 / 30.0);

    _update(dt);
    if (mounted) setState(() {});
  }

  void _update(double dt) {
    // fx update
    for (final p in fx) {
      p.t += dt;
      p.pos += Offset(p.vx, p.vy) * dt;
      p.vy += 160 * dt;
      p.vx *= pow(0.08, dt).toDouble();
    }
    fx.removeWhere((e) => e.t > e.life);

    if (gameOver) {
      cam = _lerpOffset(cam, player.head, 0.08);
      return;
    }

    // keep pellets filled
    while (pellets.length < 420) {
      pellets.add(_Pellet.random(rnd));
    }

    // player aim
    final aim = targetWorld ?? (player.head + const Offset(1, 0));
    player.update(dt, aim, pellets, fx);

    // bots
    for (final b in bots) {
      if (b.dead) continue;
      b.update(dt, _botAim(b), pellets, fx);
    }

    // collisions (IMPORTANT):
    // ✅ self-collision YOK
    // ✅ head-to-body: sadece digerlerinin body’si
    _resolveCollisionsNoSelf();

    // camera follow
    cam = _lerpOffset(cam, player.head, 0.12);

    bestLen = max(bestLen, player.length);
  }

  Offset _botAim(_Snake b) {
    // simple: nearest pellet + mild wander
    _Pellet? pick;
    double best = double.infinity;

    for (int i = 0; i < pellets.length; i += 5) {
      final p = pellets[i];
      final d = (p.pos - b.head).distanceSquared;
      if (d < best) {
        best = d;
        pick = p;
      }
    }

    var aim = pick?.pos ?? b.head;

    // avoid player if player bigger & close
    if (!player.dead && player.length > b.length + 6) {
      final d = (player.head - b.head).distance;
      if (d < 420) {
        final away = (b.head - player.head);
        if (away.distance > 0.001) {
          aim = b.head + away / away.distance * 420;
        }
      }
    }

    if (rnd.nextDouble() < 0.02) {
      aim += Offset((rnd.nextDouble() * 2 - 1) * 240, (rnd.nextDouble() * 2 - 1) * 240);
    }

    return _clampWorld(aim);
  }

  void _resolveCollisionsNoSelf() {
    final all = <_Snake>[player, ...bots];

    // 1) head into other bodies -> die
    for (final s in all) {
      if (s.dead) continue;

      bool hit = false;
      _Snake? hitOwner;

      for (final other in all) {
        if (other.dead) continue;
        if (identical(s, other)) continue; // ✅ self body tamamen ignore

        // sparse check
        for (int i = 8; i < other.points.length; i += 2) {
          final pt = other.points[i];
          final rr = s.headRadius + other.bodyRadiusAt(i) * 0.95;
          if ((pt - s.head).distanceSquared < rr * rr) {
            hit = true;
            hitOwner = other;
            break;
          }
        }
        if (hit) break;
      }

      if (hit) _killSnake(s, causedBy: hitOwner);
    }

    // 2) head-to-head: bigger wins
    for (int i = 0; i < all.length; i++) {
      final a = all[i];
      if (a.dead) continue;
      for (int j = i + 1; j < all.length; j++) {
        final b = all[j];
        if (b.dead) continue;

        final rr = a.headRadius + b.headRadius;
        if ((a.head - b.head).distanceSquared < rr * rr) {
          if (a.length == b.length) {
            _killSnake(a, causedBy: b);
            _killSnake(b, causedBy: a);
          } else if (a.length > b.length) {
            _killSnake(b, causedBy: a);
            a.boost(0.20);
          } else {
            _killSnake(a, causedBy: b);
            b.boost(0.20);
          }
        }
      }
    }
  }

  void _killSnake(_Snake s, {required _Snake? causedBy}) {
    if (s.dead) return;
    s.dead = true;

    // drop fewer pellets (simpler)
    final dropCount = (s.length * 4).clamp(30, 220);
    for (int i = 0; i < dropCount; i++) {
      final a = rnd.nextDouble() * pi * 2;
      final rad = rnd.nextDouble() * 90;
      final pos = s.head + Offset(cos(a) * rad, sin(a) * rad);
      pellets.add(_Pellet(pos: _clampWorld(pos), value: 1, hue: s.hue));
    }

    // small fx
    _confetti(s.head, hue: s.hue, power: 16);

    if (identical(s, player)) {
      gameOver = true;
    } else {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        s.respawn(Offset(rnd.nextDouble() * worldW, rnd.nextDouble() * worldH));
      });
    }
  }

  void _confetti(Offset at, {required double hue, int power = 14}) {
    for (int i = 0; i < power; i++) {
      final a = rnd.nextDouble() * pi * 2;
      final sp = 90 + rnd.nextDouble() * 180;
      fx.add(_FxDot(
        pos: at,
        vx: cos(a) * sp,
        vy: sin(a) * sp - 90,
        life: 0.55 + rnd.nextDouble() * 0.20,
        hue: (hue + rnd.nextDouble() * 0.10) % 1.0,
        size: 1.4 + rnd.nextDouble() * 2.0,
      ));
    }
  }

  Offset _screenToWorld(Offset p) {
    final topLeft = cam - Offset(screen.width / 2, screen.height / 2);
    return topLeft + p;
  }

  Offset _clampWorld(Offset p) => Offset(
        p.dx.clamp(0.0, worldW),
        p.dy.clamp(0.0, worldH),
      );

  Offset _lerpOffset(Offset a, Offset b, double t) => Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      screen = Size(c.maxWidth, c.maxHeight);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) {
          if (gameOver) return;
          targetWorld = _clampWorld(_screenToWorld(d.localPosition));
        },
        onPanUpdate: (d) {
          if (gameOver) return;
          targetWorld = _clampWorld(_screenToWorld(d.localPosition));
        },
        onTap: () {
          if (gameOver) _newGame();
        },
        child: CustomPaint(
          painter: _Painter(
            screen: screen,
            cam: cam,
            pellets: pellets,
            player: player,
            bots: bots,
            fx: fx,
            gameOver: gameOver,
            bestLen: bestLen,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

// ----------------------------
// Models
// ----------------------------

class _Pellet {
  Offset pos;
  int value;
  double hue;

  _Pellet({required this.pos, required this.value, required this.hue});

  static _Pellet random(Random rnd) {
    return _Pellet(
      pos: Offset(rnd.nextDouble() * _OrbRunnerGameState.worldW, rnd.nextDouble() * _OrbRunnerGameState.worldH),
      value: rnd.nextDouble() < 0.14 ? 2 : 1,
      hue: rnd.nextDouble(),
    );
  }
}

class _Snake {
  bool isPlayer;
  bool dead = false;

  // body points
  final List<Offset> points = [];
  final List<double> radii = [];

  Offset head;
  Offset vel = Offset.zero;

  // ✅ Slow base speed
  double baseSpeed = 150;
  double speed = 150;
  double turn = 5.8;

  int length = 6;
  double growBank = 0;

  double hue;
  double blinkT = 0;

  _Snake._({required this.isPlayer, required this.head, required this.hue}) {
    _initBody();
    _rebuildToLength();
  }

  factory _Snake.player({required Offset pos, required double hue}) {
    final s = _Snake._(isPlayer: true, head: pos, hue: hue);
    s.baseSpeed = 150; // ✅ slower
    s.speed = s.baseSpeed;
    s.turn = 6.2;
    return s;
  }

  factory _Snake.bot({required Offset pos, required double hue}) {
    final s = _Snake._(isPlayer: false, head: pos, hue: hue);
    s.baseSpeed = 140 + Random().nextDouble() * 30; // 140..170
    s.speed = s.baseSpeed;
    s.turn = 5.2 + Random().nextDouble() * 1.1;
    s.length = 7 + Random().nextInt(8);
    s._rebuildToLength();
    s._recomputeRadii();
    return s;
  }

  double get headRadius => 15 + (length * 0.34).clamp(0, 13).toDouble();

  double bodyRadiusAt(int i) {
    if (i < 0 || i >= radii.length) return headRadius * 0.60;
    return radii[i];
  }

  void _initBody() {
    points.clear();
    radii.clear();
    for (int i = 0; i < 70; i++) {
      points.add(head - Offset(i * 10.0, 0));
      radii.add(max(6.0, headRadius - i * 0.12));
    }
  }

  void _rebuildToLength() {
    final segCount = (70 + length * 4).clamp(70, 200);
    while (points.length < segCount) {
      points.add(points.last);
      radii.add(radii.last);
    }
    while (points.length > segCount) {
      points.removeLast();
      radii.removeLast();
    }
  }

  void respawn(Offset pos) {
    dead = false;
    head = pos;
    vel = Offset.zero;
    growBank = 0;
    blinkT = 0;

    length = 7 + Random().nextInt(6);
    _initBody();
    _rebuildToLength();

    // reset speed
    speed = baseSpeed;
    _recomputeRadii();
  }

  // ✅ Controlled boost (no runaway)
  void boost(double amount) {
    final factor = (1 + amount).clamp(1.0, 1.35);
    speed = min(speed * factor, baseSpeed * 1.35);
  }

  void update(double dt, Offset aim, List<_Pellet> pellets, List<_FxDot> fx) {
    if (dead) return;

    // ✅ Smooth return to base speed (dt based)
    final k = 2.6;
    speed += (baseSpeed - speed) * (k * dt);

    final to = (aim - head);
    final dir = to.distance > 0.001 ? to / to.distance : const Offset(1, 0);

    // steering
    vel = _lerp(vel, dir * speed, (turn * dt).clamp(0.0, 1.0));
    head += vel * dt;

    // clamp
    head = Offset(
      head.dx.clamp(0.0, _OrbRunnerGameState.worldW),
      head.dy.clamp(0.0, _OrbRunnerGameState.worldH),
    );

    // body follow (simple)
    points[0] = head;
    const desiredDist = 10.0;
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final delta = cur - prev;
      final dist = delta.distance;
      if (dist > desiredDist) {
        points[i] = prev + (delta / dist) * desiredDist;
      }
    }

    // eat pellets (simple)
    final eatR = headRadius + 10;
    for (int i = pellets.length - 1; i >= 0; i--) {
      final p = pellets[i];
      if ((p.pos - head).distanceSquared < eatR * eatR) {
        pellets.removeAt(i);
        growBank += p.value.toDouble();

        // tiny fx
        fx.add(_FxDot(
          pos: p.pos,
          vx: (Random().nextDouble() * 2 - 1) * 60,
          vy: -90 - Random().nextDouble() * 70,
          life: 0.40,
          hue: p.hue,
          size: 1.4 + Random().nextDouble() * 1.4,
        ));
      }
    }

    // growth
    if (growBank >= 1.0) {
      final add = growBank.floor();
      growBank -= add;

      length = (length + add).clamp(4, 1200);
      _rebuildToLength();
    }
    _recomputeRadii();

    // blink
    blinkT -= dt;
    if (blinkT <= 0 && Random().nextDouble() < 0.02) blinkT = 0.12;
  }

  void _recomputeRadii() {
    final hr = headRadius;
    for (int i = 0; i < radii.length; i++) {
      final t = i / max(1, radii.length - 1);
      radii[i] = (hr * (0.82 - t * 0.54)).clamp(6.0, hr);
    }
  }

  static Offset _lerp(Offset a, Offset b, double t) => Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      );
}

class _FxDot {
  Offset pos;
  double vx, vy;
  double t = 0;
  double life;
  double hue;
  double size;

  _FxDot({
    required this.pos,
    required this.vx,
    required this.vy,
    required this.life,
    required this.hue,
    required this.size,
  });
}

// ----------------------------
// Painter
// ----------------------------

class _Painter extends CustomPainter {
  final Size screen;
  final Offset cam;

  final List<_Pellet> pellets;
  final _Snake player;
  final List<_Snake> bots;
  final List<_FxDot> fx;

  final bool gameOver;
  final int bestLen;

  _Painter({
    required this.screen,
    required this.cam,
    required this.pellets,
    required this.player,
    required this.bots,
    required this.fx,
    required this.gameOver,
    required this.bestLen,
  });

  Offset worldToScreen(Offset w) {
    final topLeft = cam - Offset(screen.width / 2, screen.height / 2);
    return w - topLeft;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);
    _grid(canvas, size);

    // pellets
    for (final p in pellets) {
      final sp = worldToScreen(p.pos);
      if (!_onscreen(sp, size, 40)) continue;

      final col = HSVColor.fromAHSV(1.0, p.hue * 360, 0.55, 1.0).toColor();
      final r = p.value == 2 ? 4.0 : 3.0;

      final glow = Paint()
        ..shader = ui.Gradient.radial(sp, r * 4, [col.withOpacity(0.18), Colors.transparent]);
      canvas.drawCircle(sp, r * 4, glow);
      canvas.drawCircle(sp, r, Paint()..color = col.withOpacity(0.92));
    }

    // snakes
    for (final b in bots) {
      if (!b.dead) _drawSnake(canvas, size, b);
    }
    if (!player.dead) _drawSnake(canvas, size, player);

    // fx
    for (final p in fx) {
      final sp = worldToScreen(p.pos);
      if (!_onscreen(sp, size, 50)) continue;
      final a = (1 - p.t / p.life).clamp(0.0, 1.0);
      final col = HSVColor.fromAHSV(0.85 * a, p.hue * 360, 0.70, 1.0).toColor();
      canvas.drawCircle(sp, p.size, Paint()..color = col);
    }

    _hud(canvas, size);

    if (gameOver) _centerCard(canvas, size, "Game Over", "Tap to restart");
  }

  void _drawSnake(Canvas canvas, Size size, _Snake s) {
    final base = HSVColor.fromAHSV(1.0, s.hue * 360, 0.50, 1.0).toColor();
    final light = HSVColor.fromAHSV(1.0, (s.hue * 360 + 18) % 360, 0.35, 1.0).toColor();

    for (int i = s.points.length - 1; i >= 0; i--) {
      final sp = worldToScreen(s.points[i]);
      if (!_onscreen(sp, size, 80)) continue;

      final r = s.bodyRadiusAt(i);
      final glow = Paint()
        ..shader = ui.Gradient.radial(sp, r * 3.0, [base.withOpacity(0.10), Colors.transparent]);
      canvas.drawCircle(sp, r * 3.0, glow);

      final t = i / max(1, s.points.length - 1);
      final col = Color.lerp(base, light, (1 - t) * 0.35)!;
      canvas.drawCircle(sp, r, Paint()..color = col.withOpacity(0.92));
    }

    // head
    final headS = worldToScreen(s.head);
    final hr = s.headRadius;

    final headGlow = Paint()
      ..shader = ui.Gradient.radial(headS, hr * 3.4, [base.withOpacity(0.14), Colors.transparent]);
    canvas.drawCircle(headS, hr * 3.4, headGlow);

    final headPaint = Paint()
      ..shader = ui.Gradient.radial(
        headS.translate(-hr * 0.35, -hr * 0.4),
        hr * 1.8,
        [Colors.white.withOpacity(0.72), base.withOpacity(0.92)],
      );
    canvas.drawCircle(headS, hr, headPaint);

    // ears
    final earPaint = Paint()..color = base.withOpacity(0.95);
    canvas.drawCircle(headS + Offset(-hr * 0.65, -hr * 0.65), hr * 0.40, earPaint);
    canvas.drawCircle(headS + Offset(hr * 0.65, -hr * 0.65), hr * 0.40, earPaint);

    // eyes
    final eye = Paint()..color = const Color(0xFF0B0F1A).withOpacity(0.75);
    if (s.blinkT > 0) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0B0F1A).withOpacity(0.65);
      canvas.drawLine(headS + Offset(-hr * 0.34, -hr * 0.05), headS + Offset(-hr * 0.16, -hr * 0.05), line);
      canvas.drawLine(headS + Offset(hr * 0.16, -hr * 0.05), headS + Offset(hr * 0.34, -hr * 0.05), line);
    } else {
      canvas.drawCircle(headS + Offset(-hr * 0.24, -hr * 0.05), hr * 0.12, eye);
      canvas.drawCircle(headS + Offset(hr * 0.24, -hr * 0.05), hr * 0.12, eye);
    }

    // nose
    canvas.drawCircle(headS + Offset(0, hr * 0.18), hr * 0.11, Paint()..color = Colors.white.withOpacity(0.28));
  }

  void _bg(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050816), Color(0xFF120A2A), Color(0xFF07183A)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.45),
        size.shortestSide * 0.9,
        [Colors.transparent, Colors.black.withOpacity(0.55)],
      );
    canvas.drawRect(rect, vignette);
  }

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    final topLeft = cam - Offset(size.width / 2, size.height / 2);
    const step = 160.0;
    final startX = (topLeft.dx / step).floorToDouble() * step;
    final startY = (topLeft.dy / step).floorToDouble() * step;

    for (double x = startX; x < topLeft.dx + size.width + step; x += step) {
      final sx = x - topLeft.dx;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), paint);
    }
    for (double y = startY; y < topLeft.dy + size.height + step; y += step) {
      final sy = y - topLeft.dy;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), paint);
    }
  }

  void _hud(Canvas canvas, Size size) {
    final text = "Length: ${player.length}  •  Best: $bestLen";

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white.withOpacity(0.86)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(14, 14, tp.width + 20, 32),
      const Radius.circular(999),
    );

    canvas.drawRRect(r, Paint()..color = const Color(0xFF0B0F1A).withOpacity(0.62));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.10),
    );

    tp.paint(canvas, const Offset(24, 22));

    final hint = gameOver ? "Tap to restart" : "Drag to steer • Hit others = lose";
    final hp = TextPainter(
      text: TextSpan(
        text: hint,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white.withOpacity(0.68)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    hp.paint(canvas, Offset(20, size.height - 28 - hp.height));
  }

  void _centerCard(Canvas canvas, Size size, String title, String subtitle) {
    final titleP = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w900, fontSize: 30),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final subP = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.74), fontWeight: FontWeight.w800, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = max(titleP.width, subP.width) + 54;
    const h = 124.0;

    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.44), width: w, height: h),
      const Radius.circular(22),
    );

    canvas.drawRRect(card, Paint()..color = const Color(0xFF0B0F1A).withOpacity(0.78));
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.12),
    );

    titleP.paint(canvas, Offset(card.left + (w - titleP.width) / 2, card.top + 22));
    subP.paint(canvas, Offset(card.left + (w - subP.width) / 2, card.top + 74));
  }

  bool _onscreen(Offset p, Size size, double pad) =>
      p.dx > -pad && p.dx < size.width + pad && p.dy > -pad && p.dy < size.height + pad;

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) => true;
}
