import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/glass_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    final a = _a.text.trim();
    final b = _b.text.trim();
    if (a.isEmpty || b.isEmpty) return;

    setState(() => _saving = true);
    await s.setPartners(a: a, b: b);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final state = context.watch<AppState>();

    return GradientScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              t.t('appName'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              t.t('tagline'),
              textAlign: TextAlign.center,
              style: TextStyle(color: DSColors.muted.withOpacity(0.9)),
            ),
            const SizedBox(height: 18),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, color: DSColors.neonPink.withOpacity(0.95)),
                      const SizedBox(width: 10),
                      Text(
                        t.t('partners'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      _LangPill(
                        value: state.langCode,
                        onChanged: (v) => context.read<AppState>().setLanguage(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Input(
                    controller: _a,
                    label: t.t('yourName'),
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 10),
                  _Input(
                    controller: _b,
                    label: t.t('partnerName'),
                    icon: Icons.person_2,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DSColors.neonPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_saving ? '...' : t.t('save')),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tip: İsimler sonra Ayarlar’dan değişir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DSColors.muted.withOpacity(0.85), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Privacy: This is a single-phone game. Keep it fun & safe ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(color: DSColors.muted.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _Input({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LangPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: DSColors.card,
          items: [
            DropdownMenuItem(value: 'en', child: Text(t.t('english'))),
            DropdownMenuItem(value: 'tr', child: Text(t.t('turkish'))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
