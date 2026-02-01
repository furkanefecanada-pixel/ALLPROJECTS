import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'theme.dart';
import '../screens/root_gate.dart';

class DateSyncApp extends StatelessWidget {
  const DateSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().langCode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DateSync',
      theme: buildDateSyncTheme(),
      home: RootGate(key: ValueKey(lang)), // dil değişince rebuild
    );
  }
}
