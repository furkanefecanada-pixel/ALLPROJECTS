import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../widgets/gradient_scaffold.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);

    final pages = const [
      HomeScreen(),
      SettingsScreen(),
    ];

    return GradientScaffold(
      child: pages[_index],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.grid_view_rounded), label: t.t('home')),
              NavigationDestination(icon: const Icon(Icons.tune_rounded), label: t.t('settings')),
            ],
          ),
        ),
      ),
    );
  }
}
