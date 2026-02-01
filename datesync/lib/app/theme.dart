import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DSColors {
  static const bgTop = Color(0xFF1A1028);
  static const bgBottom = Color(0xFF0B0812);

  static const neonPink = Color(0xFFFF3D8D);
  static const neonRose = Color(0xFFFF6AA8);
  static const softLilac = Color(0xFFB9A6FF);

  static const card = Color(0xFF161120);
  static const card2 = Color(0xFF0F0B18);
  static const text = Color(0xFFF3F0FF);
  static const muted = Color(0xFFB9B2CC);

  static const success = Color(0xFF39E58C);
  static const warn = Color(0xFFFFC857);
  static const danger = Color(0xFFFF4D4D);
}

ThemeData buildDateSyncTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: DSColors.text,
    displayColor: DSColors.text,
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: textTheme,
    colorScheme: const ColorScheme.dark(
      primary: DSColors.neonPink,
      secondary: DSColors.softLilac,
      surface: DSColors.card,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
  );
}
