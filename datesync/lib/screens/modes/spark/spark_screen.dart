import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../l10n/strings.dart';
import '../../../state/app_state.dart';
import '../../../widgets/glass_card.dart';
import 'spark_deck.dart';

class SparkScreen extends StatefulWidget {
  const SparkScreen({super.key});

  @override
  State<SparkScreen> createState() => _SparkScreenState();
}

class _SparkScreenState extends State<SparkScreen> {
  String _prompt = '';

  void _next() {
    final state = context.read<AppState>();
    final rnd = Random();
    final list = (state.langCode == 'tr') ? SparkDeck.promptsTr : SparkDeck.promptsEn;

    setState(() {
      _prompt = list[rnd.nextInt(list.length)];
    });
  }

  @override
  void initState() {
    super.initState();
    // ilk prompt
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.t('mode_spark'))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Expanded(
              child: GlassCard(
                child: Center(
                  child: Text(
                    _prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _next,
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
