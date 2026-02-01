import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'onboarding/onboarding_screen.dart';
import 'shell/main_shell.dart';

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.hasPartners) {
      return const OnboardingScreen();
    }
    return const MainShell();
  }
}
