import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'state/app_state.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(); // ✅ options yok

  final appState = AppState();
  await appState.load();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const DateSyncApp(),
    ),
  );
}
