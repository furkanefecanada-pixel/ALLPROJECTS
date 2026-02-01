import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'games/perfect_timing_bar.dart';
import 'games/stack_tower.dart';
import 'games/tank_dash.dart';
import 'games/neon_paddle.dart';
import 'games/orb_runner_game.dart';
import 'ui/reels_overlay.dart';

import 'games/lane_dash_game.dart';
import 'games/pop_targets_game.dart';
import 'games/mini_merge_drop_game.dart';


class ReelsShell extends StatefulWidget {
  const ReelsShell({super.key});

  @override
  State<ReelsShell> createState() => _ReelsShellState();
}

class _ReelsShellState extends State<ReelsShell> {
  final _pageController = PageController();
  int _currentIndex = 0;

  // UI tuning
  static const double _bottomCaptionHeight = 240;

  // Swipe tuning (reels hissi)
  static const double _swipeThresholdPx = 70; // minimum mesafe
  static const double _verticalRatio = 1.35; // dy, dx'ten ne kadar baskın olmalı
  static const int _maxSwipeDurationMs = 420; // yavaş sürüklemeyi swipe sayma
  static const double _minVelocityPxPerMs = 1.1; // ~1100 px/s

  // Pointer tracking (Listener)
  int? _activePointer;
  Offset? _startPos;
  int _startMs = 0;

  late final List<_ReelItem> items = [
    _ReelItem(
      id: "timing",
      title: "Perfect Timing",
      subtitle: "Tap on the sweet spot. Build streaks.",
      accentA: const Color(0xFF4CC9FF),
      accentB: const Color(0xFF7C5CFF),
      game: const PerfectTimingBarGame(key: ValueKey("game_timing")),
    ),
    _ReelItem(
      id: "stack",
      title: "Stack Tower",
      subtitle: "Drop blocks. Keep overlap. Don't miss.",
      accentA: const Color(0xFFFF4D8D),
      accentB: const Color(0xFFFFC857),
      game: const StackTowerGame(key: ValueKey("game_stack")),
    ),
    _ReelItem(
      id: "tank",
      title: "Tank Dash",
      subtitle: "Drag to move. Auto-fire. Survive.",
      accentA: const Color(0xFF00F5D4),
      accentB: const Color(0xFF00BBF9),
      game: const TankDashGame(key: ValueKey("game_tank")),
    ),
    _ReelItem(
      id: "paddle",
      title: "Neon Paddle",
      subtitle: "Drag paddle. Keep the ball alive.",
      accentA: const Color(0xFFB517FF),
      accentB: const Color(0xFF00E5FF),
      game: const NeonPaddleGame(key: ValueKey("game_paddle")),
    ),
    _ReelItem(
      id: "orb",
      title: "Orb Runner",
      subtitle: "Drag to dodge. Collect orbs for points.",
      accentA: const Color(0xFFFFB703),
      accentB: const Color(0xFFFB5607),
      game: const OrbRunnerGame(key: ValueKey("game_orb")),
    ),

        _ReelItem(
      id: "lane",
      title: "Lane Dash",
      subtitle: "Tap left/right to switch lanes. Dodge the blocks.",
      accentA: const Color(0xFF00F5D4),
      accentB: const Color(0xFFFF4D8D),
      game: const LaneDashGame(key: ValueKey("game_lane")),
    ),
    _ReelItem(
      id: "pop",
      title: "Pop Targets",
      subtitle: "Tap targets before they fade. Miss = HP loss.",
      accentA: const Color(0xFF4CC9FF),
      accentB: const Color(0xFFFFB703),
      game: const PopTargetsGame(key: ValueKey("game_pop")),
    ),
    _ReelItem(
      id: "merge",
      title: "Mini Merge Drop",
      subtitle: "Drag column, tap drop. Merge same tiles to level up.",
      accentA: const Color(0xFF7C5CFF),
      accentB: const Color(0xFF00BBF9),
      game: const MiniMergeDropGame(key: ValueKey("game_merge")),
    ),

  ];

  late final Map<String, _ReelSocial> _socialById = {
    for (final it in items) it.id: _ReelSocial.seeded(it.id),
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goTo(int next) async {
    if (next < 0 || next >= items.length) return;
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ✅ Manuel swipe: oyun dokunmasını bozmaz (Listener tüketmez)
  void _onPointerDown(PointerDownEvent e) {
    if (_activePointer != null) return;
    _activePointer = e.pointer;
    _startPos = e.position;
    _startMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;

    final start = _startPos;
    _activePointer = null;
    _startPos = null;

    if (start == null) return;

    final end = e.position;
    final delta = end - start;
    final dx = delta.dx.abs();
    final dy = delta.dy.abs();

    // Mesafe
    if (dy < _swipeThresholdPx) return;

    // Yön baskınlığı (dikey mi?)
    if (dy < dx * _verticalRatio) return;

    // Hız / süre kontrolü (yavaş oyun drag'ini swipe sayma)
    final now = DateTime.now().millisecondsSinceEpoch;
    final dur = max(1, now - _startMs);
    final v = dy / dur; // px/ms

    if (dur > _maxSwipeDurationMs && v < _minVelocityPxPerMs) {
      return;
    }

    // Reels mantığı: yukarı sürükle => next, aşağı => prev
    final next = delta.dy < 0 ? _currentIndex + 1 : _currentIndex - 1;
    if (next == _currentIndex) return;

    _goTo(next);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer == _activePointer) {
      _activePointer = null;
      _startPos = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          // ✅ Native scroll kapalı: swipe'ı biz yönetiyoruz
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final item = items[index];
            final social = _socialById[item.id]!;
            final isCurrent = index == _currentIndex;

            return _KeepAlivePage(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ Oyun direkt oynanır (Play/Exit yok)
                  // Performans: sadece current sayfa ticker çalışsın
                  TickerMode(
                    enabled: isCurrent,
                    child: item.game,
                  ),

                  // top fade
                  IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Color(0xB0000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),

                  // bottom fade
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: _bottomCaptionHeight,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xCC000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Overlay (like/comment/save/share)
                  ReelsOverlay(
                    appName: "GameScroll",
                    title: item.title,
                    subtitle: item.subtitle,
                    accentA: item.accentA,
                    accentB: item.accentB,
                    social: social,
                    onToggleLike: () => setState(social.toggleLike),
                    onToggleSave: () => setState(social.toggleSave),
                    onShare: () {
                      setState(social.bumpShare);
                      _toast(context, "Shared (offline demo)");
                    },
                    onOpenComments: () async {
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => CommentsSheet(
                          accentA: item.accentA,
                          accentB: item.accentB,
                          state: social,
                          onChanged: () => setState(() {}),
                        ),
                      );
                    },
                  ),

                  // Swipe hint (opsiyonel)
                  if (isCurrent)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: IgnorePointer(
                        child: SafeArea(
                          top: false,
                          child: Opacity(
                            opacity: 0.55,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.keyboard_arrow_up_rounded, size: 26),
                                SizedBox(height: 2),
                                Text(
                                  "Swipe for more games",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ReelItem {
  final String id;
  final String title;
  final String subtitle;
  final Widget game;
  final Color accentA;
  final Color accentB;

  _ReelItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.game,
    required this.accentA,
    required this.accentB,
  });
}

/// ✅ ReelSocialState yerine local mini state
class _ReelSocial {
  bool liked = false;
  bool saved = false;

  int likes;
  int saves;
  int shares;

  final List<_Comment> comments;
  int get commentsCount => comments.length;

  _ReelSocial({
    required this.likes,
    required this.saves,
    required this.shares,
    required this.comments,
  });

  static _ReelSocial seeded(String seed) {
    final base = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return _ReelSocial(
      likes: 1200 + (base % 900),
      saves: 220 + (base % 120),
      shares: 40 + (base % 35),
      comments: [
        _Comment(user: "Alex", text: "This is fun 🔥", minutesAgo: 8),
        _Comment(user: "Mina", text: "Nice idea!", minutesAgo: 21),
      ],
    );
  }

  void toggleLike() {
    liked = !liked;
    likes += liked ? 1 : -1;
    likes = max(0, likes);
  }

  void toggleSave() {
    saved = !saved;
    saves += saved ? 1 : -1;
    saves = max(0, saves);
  }

  void bumpShare() => shares++;

  void addComment(String text) {
    comments.insert(0, _Comment(user: "You", text: text, minutesAgo: 0));
  }
}

class _Comment {
  final String user;
  final String text;
  final int minutesAgo;

  _Comment({required this.user, required this.text, required this.minutesAgo});
}

/// ✅ PageView builder sayfaları öldürüp diriltmesin
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
