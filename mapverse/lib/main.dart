import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_screen.dart';
import 'inventory_screen.dart';
import 'game_logic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS: portrait lock (no rotation)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Fullscreen-ish (iOS safe)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await GameLogic.I.init();
  runApp(const MapVerseApp());
}

class MapVerseApp extends StatelessWidget {
  const MapVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'GTA',
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        canvasColor: const Color(0xFF0B0B0B),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0F1217),
          primary: Color(0xFFB24CFF),
        ),
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          MapScreen(),
          InventoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'MAP'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'INVENTORY'),
        ],
      ),
    );
  }
}