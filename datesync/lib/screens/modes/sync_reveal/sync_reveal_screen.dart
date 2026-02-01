import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme.dart';
import '../../../l10n/strings.dart';
import '../../../state/app_state.dart';
import '../../../widgets/glass_card.dart';
import 'sync_deck.dart';
import 'sync_models.dart';

class SyncRevealScreen extends StatefulWidget {
  const SyncRevealScreen({super.key});

  @override
  State<SyncRevealScreen> createState() => _SyncRevealScreenState();
}

class _SyncRevealScreenState extends State<SyncRevealScreen> {
  int _index = 0;

  // READY kaldırıyoruz: herkes her tur otomatik hazır
  int _secondsLeft = 6;
  Timer? _timer;

  int? _leftPick;  // 0 = Me, 1 = You (LEFT player's perspective)
  int? _rightPick; // 0 = Me, 1 = You (RIGHT player's perspective)

  bool _revealed = false;
  bool _match = false;

  String _miniText = '';
  String _pickedPerson = ''; // match olursa: kim çıktı?

  int _streak = 0;
  int _best = 0;

  SyncQuestion get q => SyncDeck.questions[_index];

  @override
  void initState() {
    super.initState();
    // ilk tur direkt başlasın
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRound());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRound() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 6; // daha hızlı/heyecanlı
      _leftPick = null;
      _rightPick = null;
      _revealed = false;
      _match = false;
      _miniText = '';
      _pickedPerson = '';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        t.cancel();
        _reveal(force: true);
      }
    });
  }

  /// "Me/You" -> mutlak kişi çevirimi
  /// abs: 0 = left person (partnerA), 1 = right person (partnerB)
  int? _toAbsolutePick({required bool isLeftSide, required int? pick}) {
    if (pick == null) return null;

    // Left oyuncu:
    //   Me -> left (0)
    //   You -> right (1)
    // Right oyuncu:
    //   Me -> right (1)
    //   You -> left (0)
    if (isLeftSide) {
      return (pick == 0) ? 0 : 1;
    } else {
      return (pick == 0) ? 1 : 0;
    }
  }

  void _reveal({bool force = false}) {
    if (_revealed) return;

    final state = context.read<AppState>();
    final lang = state.langCode;

    final absLeft = _toAbsolutePick(isLeftSide: true, pick: _leftPick);
    final absRight = _toAbsolutePick(isLeftSide: false, pick: _rightPick);

    final hasBoth = (absLeft != null && absRight != null);

    // ikisi de seçim yaptıysa: aynı kişiyse MATCH
    final match = hasBoth && (absLeft == absRight);

    // match olduysa hangi kişi çıktı?
    String pickedPerson = '';
    if (match) {
      final who = absLeft; // ikisi aynı zaten
      pickedPerson = (who == 0) ? state.partnerA : state.partnerB;
    }

    // mini text seç
    final rnd = Random();
    String mini;
    if (!hasBoth && force) {
      // süre bitti ama biri/ikisi seçmedi
      mini = (lang == 'tr')
          ? 'İkiniz de seçin. Hızlı ol!'
          : 'Both must pick. Be faster!';
    } else if (match) {
      final list = (lang == 'tr') ? q.bonusTr : q.bonusEn;
      mini = list.isEmpty ? '' : list[rnd.nextInt(list.length)];
    } else {
      final list = (lang == 'tr') ? q.explainTr : q.explainEn;
      mini = list.isEmpty ? '' : list[rnd.nextInt(list.length)];
    }

    setState(() {
      _revealed = true;
      _match = match;
      _miniText = mini;
      _pickedPerson = pickedPerson;

      if (match) {
        _streak++;
        if (_streak > _best) _best = _streak;
      } else {
        _streak = 0; // heyecan: streak reset
      }
    });
  }

  void _nextRound() {
    _timer?.cancel();
    setState(() {
      _index = (_index + 1) % SyncDeck.questions.length;
    });
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final state = context.watch<AppState>();

    final options = (state.langCode == 'tr') ? q.optionsTr : q.optionsEn;
    final prompt = (state.langCode == 'tr') ? q.promptTr : q.promptEn;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(t.t('mode_sync')),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    prompt,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(text: state.partnerA, color: DSColors.softLilac),
                      const SizedBox(width: 8),
                      _Badge(text: state.partnerB, color: DSColors.neonRose),
                      const Spacer(),
                      _Badge(text: '🔥 $_streak', color: DSColors.neonPink),
                      const SizedBox(width: 8),
                      _Badge(text: '🏆 $_best', color: DSColors.success),
                      const SizedBox(width: 8),
                      if (!_revealed)
                        _Badge(
                          text: '${t.t('sync_pick_in')} $_secondsLeft',
                          color: DSColors.warn,
                        ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 180.ms),

            const SizedBox(height: 10),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _SidePane(
                      title: state.partnerA,
                      accent: DSColors.softLilac,
                      revealed: _revealed,
                      pickedIndex: _leftPick,
                      options: options,
                      onPick: (i) {
                        if (_revealed) return;
                        setState(() => _leftPick = i);

                        if (_leftPick != null && _rightPick != null) {
                          _timer?.cancel();
                          _reveal();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SidePane(
                      title: state.partnerB,
                      accent: DSColors.neonRose,
                      revealed: _revealed,
                      pickedIndex: _rightPick,
                      options: options,
                      onPick: (i) {
                        if (_revealed) return;
                        setState(() => _rightPick = i);

                        if (_leftPick != null && _rightPick != null) {
                          _timer?.cancel();
                          _reveal();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (_revealed)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _match ? t.t('sync_match') : t.t('sync_mismatch'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _match ? DSColors.success : DSColors.warn,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // match olunca "kim çıktı" yaz
                    if (_match && _pickedPerson.isNotEmpty)
                      Text(
                        (state.langCode == 'tr')
                            ? 'Seçilen kişi: $_pickedPerson'
                            : 'Picked person: $_pickedPerson',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                      ),

                    const SizedBox(height: 10),
                    if (_miniText.isNotEmpty)
                      Text(
                        _miniText,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      t.t('sync_talk'),
                      style: TextStyle(color: DSColors.muted.withOpacity(0.9), fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Next daha hızlı hissiyat: buton hep aynı
                    ElevatedButton(
                      onPressed: _nextRound,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DSColors.neonPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(t.t('next')),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 160.ms)
                  .scale(begin: const Offset(0.98, 0.98), end: const Offset(1.0, 1.0)),
          ],
        ),
      ),
    );
  }
}

class _SidePane extends StatelessWidget {
  final String title;
  final Color accent;

  final bool revealed;
  final int? pickedIndex;

  final List<String> options;
  final ValueChanged<int> onPick;

  const _SidePane({
    required this.title,
    required this.accent,
    required this.revealed,
    required this.pickedIndex,
    required this.options,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  _PickButton(
                    text: options[i],
                    accent: accent,
                    selected: pickedIndex == i,
                    disabled: revealed || pickedIndex != null,
                    onTap: () => onPick(i),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final String text;
  final Color accent;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _PickButton({
    required this.text,
    required this.accent,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? accent.withOpacity(0.22) : Colors.white.withOpacity(0.06);
    final border = selected ? accent.withOpacity(0.65) : Colors.white.withOpacity(0.10);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: bg,
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: disabled ? DSColors.muted : DSColors.text,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.16),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
