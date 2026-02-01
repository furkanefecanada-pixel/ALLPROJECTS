import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../l10n/strings.dart';
import '../../../state/app_state.dart';
import '../../../widgets/glass_card.dart';
import 'truth_dare_deck.dart';

class TruthDareScreen extends StatefulWidget {
  const TruthDareScreen({super.key});

  @override
  State<TruthDareScreen> createState() => _TruthDareScreenState();
}

class _TruthDareScreenState extends State<TruthDareScreen> {
  int _turn = 0; // 0 => A, 1 => B, 2 => A, ...
  String _cardText = '';
  String _type = ''; // truth / dare

  void _draw(String type) {
    final state = context.read<AppState>();
    final rnd = Random();
    final tr = state.langCode == 'tr';

    final list = type == 'truth'
        ? (tr ? ToDDeck.truthTr : ToDDeck.truthEn)
        : (tr ? ToDDeck.dareTr : ToDDeck.dareEn);

    final text = list[rnd.nextInt(list.length)];

    setState(() {
      _type = type;
      _cardText = text;
    });
  }

  void _nextTurn() {
    setState(() {
      _turn++;
      _type = '';
      _cardText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final state = context.watch<AppState>();
    final currentPlayer = (_turn % 2 == 0) ? state.partnerA : state.partnerB;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.t('mode_tod'))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            GlassCard(
              child: Row(
                children: [
                  Text('${t.t('for_player')}: ', style: TextStyle(color: DSColors.muted.withOpacity(0.95))),
                  Expanded(
                    child: Text(currentPlayer, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: GlassCard(
                child: Center(
                  child: (_cardText.isEmpty)
                      ? Text(
                          t.t('tod_pick'),
                          style: TextStyle(color: DSColors.muted.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _type.toUpperCase(),
                              style: TextStyle(
                                color: _type == 'truth' ? DSColors.softLilac : DSColors.neonRose,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _cardText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_cardText.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _draw('truth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DSColors.softLilac.withOpacity(0.25),
                        foregroundColor: DSColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(t.t('truth')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _draw('dare'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DSColors.neonRose.withOpacity(0.25),
                        foregroundColor: DSColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(t.t('dare')),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _nextTurn,
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
      ),
    );
  }
}
