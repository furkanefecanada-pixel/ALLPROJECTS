import 'package:flutter/material.dart';

class ReelsOverlay extends StatelessWidget {
  final String appName;
  final String title;
  final String subtitle;
  final Color accentA;
  final Color accentB;

  final dynamic social;

  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;

  const ReelsOverlay({
    super.key,
    required this.appName,
    required this.title,
    required this.subtitle,
    required this.accentA,
    required this.accentB,
    required this.social,
    required this.onToggleLike,
    required this.onOpenComments,
    required this.onToggleSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          /// ✅ 1) Dekor katmanı: dokunma ALMAZ
          IgnorePointer(
            ignoring: true,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 96, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [accentA, accentB]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.grid_view_rounded, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              appName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.94),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.78), height: 1.2),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.music_note, size: 16, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            Text(
                              "Trending • $appName Vibes",
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.78)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ✅ 2) Interactive katman: sadece butonlar
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: social.liked ? Icons.favorite : Icons.favorite_border,
                    label: _format(social.likes as int),
                    active: social.liked as bool,
                    accentA: accentA,
                    accentB: accentB,
                    onTap: onToggleLike,
                  ),
                  const SizedBox(height: 14),
                  _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    label: _format(social.commentsCount as int),
                    active: false,
                    accentA: accentA,
                    accentB: accentB,
                    onTap: onOpenComments,
                  ),
                  const SizedBox(height: 14),
                  _ActionButton(
                    icon: social.saved ? Icons.bookmark : Icons.bookmark_border,
                    label: _format(social.saves as int),
                    active: social.saved as bool,
                    accentA: accentA,
                    accentB: accentB,
                    onTap: onToggleSave,
                  ),
                  const SizedBox(height: 14),
                  _ActionButton(
                    icon: Icons.send,
                    label: _format(social.shares as int),
                    active: false,
                    accentA: accentA,
                    accentB: accentB,
                    onTap: onShare,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return "$n";
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accentA;
  final Color accentB;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.accentA,
    required this.accentB,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = Colors.white.withOpacity(0.14);
    final bg = const Color(0xFF0B0F1A).withOpacity(0.75);

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: accentA.withOpacity(0.22),
                        blurRadius: 18,
                        spreadRadius: 1,
                      )
                    ]
                  : const [],
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: active ? [accentA, accentB] : [Colors.white, Colors.white],
                ).createShader(r),
                blendMode: BlendMode.srcIn,
                child: Icon(icon, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.86), fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// ----------------------
/// Comments Bottom Sheet (aynı kaldı)
/// ----------------------
class CommentsSheet extends StatefulWidget {
  final Color accentA;
  final Color accentB;
  final dynamic state;
  final VoidCallback onChanged;

  const CommentsSheet({
    super.key,
    required this.accentA,
    required this.accentB,
    required this.state,
    required this.onChanged,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.state.addComment(text);
    _controller.clear();
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Container(
      height: h * 0.72,
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text("Comments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.75)),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              itemCount: (widget.state.comments as List).length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.06)),
              itemBuilder: (context, i) {
                final c = widget.state.comments[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [widget.accentA, widget.accentB]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          (c.user as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.user, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Text(
                                "${c.minutesAgo}m",
                                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c.text, style: TextStyle(color: Colors.white.withOpacity(0.88))),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: "Add a comment…",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                        filled: true,
                        fillColor: const Color(0xFF0B0F1A).withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [widget.accentA, widget.accentB]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
