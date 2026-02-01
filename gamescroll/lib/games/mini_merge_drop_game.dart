import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class MiniMergeDropGame extends StatefulWidget {
  const MiniMergeDropGame({super.key});

  @override
  State<MiniMergeDropGame> createState() => _MiniMergeDropGameState();
}

class _MiniMergeDropGameState extends State<MiniMergeDropGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  static const int cols = 6;
  static const int rows = 8;

  Size _size = const Size(400, 800);
  bool _inited = false;

  // board values: 0 empty, 1..n levels
  final List<List<int>> grid = List.generate(rows, (_) => List.filled(cols, 0));

  int score = 0;
  int bestChain = 0;
  int chainNow = 0;
  bool gameOver = false;

  // control
  int selCol = 2;
  double timeAlive = 0;

  // falling piece
  _Falling? fall;

  final _rnd = Random();

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
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        grid[r][c] = 0;
      }
    }
    score = 0;
    bestChain = 0;
    chainNow = 0;
    timeAlive = 0;
    gameOver = false;
    selCol = cols ~/ 2;
    fall = null;
    _last = Duration.zero;
  }

  int _level() {
    // just for display / pacing
    return 1 + (score ~/ 20);
  }

  void _onDrag(Offset p) {
    if (gameOver) return;
    if (fall != null) return;
    final cellW = _boardW() / cols;
    final left = (_size.width - _boardW()) / 2;
    final x = (p.dx - left) / cellW;
    selCol = x.floor().clamp(0, cols - 1);
  }

  void _drop() {
    if (gameOver) {
      _reset(_size);
      return;
    }
    if (fall != null) return;

    final row = _findDropRow(selCol);
    if (row < 0) {
      gameOver = true;
      return;
    }

    // next tile level (viral feel): mostly 1, sometimes 2
    final lvl = (_level() >= 4 && _rnd.nextDouble() < 0.18) ? 2 : 1;

    fall = _Falling(col: selCol, targetRow: row, y: -1.2, level: lvl);
  }

  int _findDropRow(int col) {
    for (int r = rows - 1; r >= 0; r--) {
      if (grid[r][col] == 0) return r;
    }
    return -1;
  }

  double _boardW() => min(_size.width * 0.88, 420);
  double _boardH() => min(_size.height * 0.58, 520);

  void _update(double dt) {
    if (!_inited || gameOver) return;
    timeAlive += dt;

    // falling animation
    if (fall != null) {
      // fall speed increases slightly with score
      final v = (7.5 + min(4.0, score * 0.03));
      fall!.y += v * dt;

      if (fall!.y >= fall!.targetRow.toDouble()) {
        // settle
        grid[fall!.targetRow][fall!.col] = fall!.level;
        fall = null;

        // resolve merges + gravity (chain)
        final chain = _resolveAllMerges();
        chainNow = chain;
        bestChain = max(bestChain, chain);

        // if move caused full top, game over next attempt
      }
    }
  }

  int _resolveAllMerges() {
    int chain = 0;

    while (true) {
      final groups = _findMergeGroups();
      if (groups.isEmpty) break;

      chain += 1;

      // Merge each group: pick an anchor cell (lowest row) to receive +1
      for (final g in groups) {
        g.sort((a, b) => b.r.compareTo(a.r)); // lowest first
        final anchor = g.first;
        final lvl = grid[anchor.r][anchor.c];

        // clear all
        for (final cell in g) {
          grid[cell.r][cell.c] = 0;
        }

        // anchor upgraded
        grid[anchor.r][anchor.c] = min(lvl + 1, 9);

        // score bump per group
        score += 2 * lvl + (g.length >= 3 ? 2 : 0);
      }

      _applyGravity();
    }

    return chain;
  }

  List<List<_Cell>> _findMergeGroups() {
    final seen = List.generate(rows, (_) => List.filled(cols, false));
    final groups = <List<_Cell>>[];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final v = grid[r][c];
        if (v == 0 || seen[r][c]) continue;

        final q = <_Cell>[];
        final out = <_Cell>[];
        q.add(_Cell(r, c));
        seen[r][c] = true;

        while (q.isNotEmpty) {
          final cur = q.removeLast();
          out.add(cur);

          const dirs = [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1],
          ];
          for (final d in dirs) {
            final nr = cur.r + d[0];
            final nc = cur.c + d[1];
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            if (seen[nr][nc]) continue;
            if (grid[nr][nc] != v) continue;
            seen[nr][nc] = true;
            q.add(_Cell(nr, nc));
          }
        }

        // merge rule: group size >= 2
        if (out.length >= 2) groups.add(out);
      }
    }

    return groups;
  }

  void _applyGravity() {
    for (int c = 0; c < cols; c++) {
      int write = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        final v = grid[r][c];
        if (v != 0) {
          grid[r][c] = 0;
          grid[write][c] = v;
          write--;
        }
      }
      for (; write >= 0; write--) {
        grid[write][c] = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = Size(c.maxWidth, c.maxHeight);
      if (!_inited) _reset(s);
      _size = s;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _onDrag(d.localPosition),
        onPanUpdate: (d) => _onDrag(d.localPosition),
        onTap: _drop,
        onDoubleTap: () => _reset(_size),
        child: CustomPaint(
          painter: _MiniMergePainter(
            grid: grid,
            selCol: selCol,
            fall: fall,
            score: score,
            level: _level(),
            chainNow: chainNow,
            bestChain: bestChain,
            gameOver: gameOver,
            timeAlive: timeAlive,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

class _Cell {
  final int r, c;
  _Cell(this.r, this.c);
}

class _Falling {
  final int col;
  final int targetRow;
  double y; // row-space float
  final int level;
  _Falling({required this.col, required this.targetRow, required this.y, required this.level});
}

class _MiniMergePainter extends CustomPainter {
  final List<List<int>> grid;
  final int selCol;
  final _Falling? fall;

  final int score;
  final int level;
  final int chainNow;
  final int bestChain;
  final bool gameOver;
  final double timeAlive;

  _MiniMergePainter({
    required this.grid,
    required this.selCol,
    required this.fall,
    required this.score,
    required this.level,
    required this.chainNow,
    required this.bestChain,
    required this.gameOver,
    required this.timeAlive,
  });

  static const int cols = MiniMergeDropGameState.colsFallback;
  static const int rows = MiniMergeDropGameState.rowsFallback;

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

    // dust
    final dot = Paint()..color = Colors.white.withOpacity(0.04);
    for (double y = 0; y < size.height; y += 28) {
      for (double x = 0; x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }

    // board layout
    final boardW = min(size.width * 0.88, 420.0);
    final boardH = min(size.height * 0.58, 520.0);
    final left = (size.width - boardW) / 2;
    final top = size.height * 0.22;
    final cellW = boardW / cols;
    final cellH = boardH / rows;

    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boardW, boardH),
      const Radius.circular(22),
    );

    // board base
    canvas.drawRRect(
      boardRect,
      Paint()..color = const Color(0xFF0B0F1A).withOpacity(0.74),
    );

    // selection column glow
    final selX = left + selCol * cellW + cellW / 2;
    canvas.drawRect(
      Rect.fromLTWH(left + selCol * cellW, top, cellW, boardH),
      Paint()
        ..color = const Color(0xFF7C5CFF).withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      Offset(selX, top - 16),
      12,
      Paint()..color = Colors.white.withOpacity(0.42),
    );

    // grid lines
    final line = Paint()..color = Colors.white.withOpacity(0.06);
    for (int i = 1; i < cols; i++) {
      canvas.drawRect(Rect.fromLTWH(left + i * cellW - 0.5, top, 1, boardH), line);
    }
    for (int i = 1; i < rows; i++) {
      canvas.drawRect(Rect.fromLTWH(left, top + i * cellH - 0.5, boardW, 1), line);
    }

    // tiles
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final v = grid[r][c];
        if (v == 0) continue;

        final cx = left + c * cellW + cellW / 2;
        final cy = top + r * cellH + cellH / 2;
        _drawTile(canvas, Offset(cx, cy), min(cellW, cellH) * 0.34, v);
      }
    }

    // falling tile
    if (fall != null) {
      final cx = left + fall!.col * cellW + cellW / 2;
      final cy = top + fall!.y * cellH + cellH / 2;
      _drawTile(canvas, Offset(cx, cy), min(cellW, cellH) * 0.34, fall!.level);
    }

    // hint
    if (!gameOver && timeAlive < 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: "Drag to choose column • Tap to drop\nMerge same tiles (2+) → level up",
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
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.14));
    }

    if (!gameOver && chainNow >= 2) {
      final tp = TextPainter(
        text: TextSpan(
          text: "CHAIN x$chainNow",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4CC9FF).withOpacity(0.9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 16, size.height * 0.20));
    }

    if (gameOver) {
      final tp = TextPainter(
        text: TextSpan(
          text: "NO SPACE\nScore: $score\nBest chain: $bestChain\nLvl: $level\n\nTap to restart",
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

      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.70 - tp.height));
    }

    // bottom HUD
    final hud = TextPainter(
      text: TextSpan(
        text: "Score $score   Lvl $level   Best chain $bestChain",
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

  void _drawTile(Canvas canvas, Offset c, double r, int level) {
    // palette by level (simple, neon)
    final palette = const [
      Color(0xFF4CC9FF),
      Color(0xFF7C5CFF),
      Color(0xFF00F5D4),
      Color(0xFFFFB703),
      Color(0xFFFF4D8D),
      Color(0xFFFB5607),
      Color(0xFFB517FF),
      Color(0xFF00BBF9),
      Color(0xFFFFFFFF),
    ];
    final a = palette[(level - 1).clamp(0, palette.length - 1)];
    final b = palette[(level).clamp(0, palette.length - 1)];

    canvas.drawCircle(
      c,
      r + 16,
      Paint()
        ..color = a.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [a.withOpacity(0.95), b.withOpacity(0.70)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: "$level",
        style: TextStyle(
          fontSize: r * 0.95,
          fontWeight: FontWeight.w900,
          color: Colors.white.withOpacity(0.90),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MiniMergePainter oldDelegate) => true;
}

/// Small trick: allow painter to compile without importing state
class MiniMergeDropGameState {
  static const int colsFallback = 6;
  static const int rowsFallback = 8;
}
