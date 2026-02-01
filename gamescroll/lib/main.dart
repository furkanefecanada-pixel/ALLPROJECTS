import 'package:flutter/material.dart';
import 'reels_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GameScrollApp());
}

class GameScrollApp extends StatelessWidget {
  const GameScrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameScroll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamilyFallback: const ["SF Pro Display", "Inter", "Roboto"],
      ),
      home: const ReelsShell(),
    );
  }
}
