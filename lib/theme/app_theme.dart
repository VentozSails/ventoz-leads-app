import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const navy = Color(0xFF1B2A4A);
  static const gold = Color(0xFFC8A85C);

  static const _primary = navy;
  static const _primaryDark = Color(0xFF0F1B33);
  static const _accent = gold;
  static const _surface = Color(0xFFF8FAFB);
  static const _cardColor = Colors.white;

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _accent,
        surface: _surface,
      ),
      scaffoldBackgroundColor: _surface,
      cardTheme: const CardThemeData(
        color: _cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F4FF)),
        headingTextStyle: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
          color: _primaryDark,
          fontSize: 13,
        ),
        dataTextStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF334155)),
        dividerThickness: 1,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 52,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
    );
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'nieuw':
        return const Color(0xFF1E88E5);
      case 'aangeboden':
        return const Color(0xFFF59E0B);
      case 'klant':
        return const Color(0xFF43A047);
      case 'niet interessant':
        return const Color(0xFFE53935);
      default:
        return Colors.blueGrey;
    }
  }
}
