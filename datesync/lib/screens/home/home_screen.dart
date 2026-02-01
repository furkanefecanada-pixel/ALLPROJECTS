import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../modes/sync_reveal/sync_reveal_screen.dart';
import '../modes/truth_dare/truth_dare_screen.dart';
import '../modes/spark/spark_screen.dart';
import '../modes/roulette/roulette_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListView(
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('appName'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tonight, play together ✨',
                    style: TextStyle(color: DSColors.muted.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              _CouplePill(a: state.partnerA, b: state.partnerB),
            ],
          ),
          const SizedBox(height: 14),

          // Hero card (relationship vibe)
          GlassCard(
            child: _HeroDateCard(
              title: t.t('mode_sync'),
              subtitle: t.t('mode_sync_sub'),
              primaryCta: t.t('start'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncRevealScreen()));
              },
            ),
          ).animate().fadeIn(duration: 280.ms).moveY(begin: 10, end: 0),

          const SizedBox(height: 16),

          // Section title
          Row(
            children: [
              Text(
  t.t('modes'),
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
),

              const Spacer(),
              _MiniBadge(text: 'NEW', color: DSColors.neonPink),
            ],
          ),
          const SizedBox(height: 10),

          // Modes grid-ish feel (still list, but premium cards)
          _ModeCardPro(
            title: 'Photo Roulette',
            subtitle: 'Spin together and reveal a surprise photo.',
            icon: Icons.casino_rounded,
            accent: DSColors.neonPink,
            tag: 'Fun',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RouletteScreen())),
          ).animate().fadeIn(duration: 260.ms, delay: 40.ms).moveY(begin: 8, end: 0),

          const SizedBox(height: 10),

          _ModeCardPro(
            title: t.t('mode_tod'),
            subtitle: t.t('mode_tod_sub'),
            icon: Icons.local_fire_department_rounded,
            accent: DSColors.neonRose,
            tag: 'Hot',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TruthDareScreen())),
          ).animate().fadeIn(duration: 260.ms, delay: 80.ms).moveY(begin: 8, end: 0),

          const SizedBox(height: 10),

          _ModeCardPro(
            title: t.t('mode_spark'),
            subtitle: t.t('mode_spark_sub'),
            icon: Icons.auto_awesome_rounded,
            accent: DSColors.softLilac,
            tag: 'Deep',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SparkScreen())),
          ).animate().fadeIn(duration: 260.ms, delay: 120.ms).moveY(begin: 8, end: 0),

          const SizedBox(height: 16),

          // Upcoming section (more premium than a plain text line)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: DSColors.muted.withOpacity(0.9), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Upcoming',
                      style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      'soon',
                      style: TextStyle(color: DSColors.muted.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _UpcomingRow(icon: Icons.nightlife_rounded, text: 'Date Night Themes'),
                const SizedBox(height: 8),
                _UpcomingRow(icon: Icons.quiz_rounded, text: 'Mini Quizzes'),
                const SizedBox(height: 8),
                _UpcomingRow(icon: Icons.lock_rounded, text: 'Spicy Pack (optional)'),
              ],
            ),
          ).animate().fadeIn(duration: 260.ms, delay: 160.ms).moveY(begin: 8, end: 0),

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _CouplePill extends StatelessWidget {
  final String a;
  final String b;

  const _CouplePill({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(blurRadius: 22, offset: Offset(0, 14), color: Color(0x22000000)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, color: Color(0xFFFF5A7A), size: 16),
          const SizedBox(width: 8),
          Text(
            '$a × $b',
            style: TextStyle(color: DSColors.muted.withOpacity(0.95), fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HeroDateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryCta;
  final VoidCallback onTap;

  const _HeroDateCard({
    required this.title,
    required this.subtitle,
    required this.primaryCta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // gradient overlay look (without breaking GlassCard)
    final g = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DSColors.neonPink.withOpacity(0.18),
        DSColors.softLilac.withOpacity(0.10),
        Colors.transparent,
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: g,
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _MiniBadge(text: 'TONIGHT', color: DSColors.neonPink),
                const SizedBox(width: 8),
                Text(
                  'Couple Mode',
                  style: TextStyle(color: DSColors.muted.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: DSColors.muted.withOpacity(0.95), height: 1.25),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: DSColors.neonPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded),
                  const SizedBox(width: 8),
                  Text(primaryCta, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _UpcomingRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DSColors.muted.withOpacity(0.85)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: DSColors.muted.withOpacity(0.7)),
      ],
    );
  }
}

/// Pro card: relationship game menu vibe
class _ModeCardPro extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String tag;
  final VoidCallback onTap;

  const _ModeCardPro({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Stack(
        children: [
          // soft accent glow
          Positioned(
            right: -26,
            top: -26,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.10),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                      color: accent.withOpacity(0.12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.26),
                      accent.withOpacity(0.12),
                    ],
                  ),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Icon(icon, color: Colors.white.withOpacity(0.92)),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.86),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: DSColors.muted.withOpacity(0.9), fontSize: 12, height: 1.2),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: DSColors.muted.withOpacity(0.9)),
            ],
          ),
        ],
      ),
    );
  }
}
