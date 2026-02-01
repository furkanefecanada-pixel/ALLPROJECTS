import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListView(
        children: [
          Text(t.t('settings'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),

          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.t('language'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.langCode,
                    dropdownColor: DSColors.card,
                    items: [
                      DropdownMenuItem(value: 'en', child: Text(t.t('english'))),
                      DropdownMenuItem(value: 'tr', child: Text(t.t('turkish'))),
                    ],
                    onChanged: (v) {
                      if (v != null) context.read<AppState>().setLanguage(v);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.t('partners'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '${state.partnerA} × ${state.partnerB}',
                  style: TextStyle(color: DSColors.muted.withOpacity(0.95)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.read<AppState>().resetPartners(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DSColors.neonRose,
                    side: BorderSide(color: DSColors.neonRose.withOpacity(0.55)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(t.t('resetNames')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
