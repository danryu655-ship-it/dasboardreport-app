import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — PERSIS dari `:root` di index.html web app.
/// Jangan ubah warna/skema: elegan = presentasi lebih rapi, bukan tema baru.
class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color muted = Color(0xFF8E8E93);
  static const Color gray = Color(0xFFF2F2F7);
  static const Color pageBg = Color(0xFFF5F5F5);
  static const Color navDark = Color(0xFF1C1C1E);
  static const Color purple = Color(0xFF9B65F7);
  static const Color blue = Color(0xFF2A94F6);
  static const Color green = Color(0xFF0DB35C);
  static const Color orange = Color(0xFFF2780C);
  static const Color danger = Color(0xFFFF3B30);
  static const Color border = Color(0xFFE5E5EA);
  static const Color amber = Color(0xFFFBBF24);
  static const Color deepPurple = Color(0xFF4338CA);
  static const Color deepPurpleDark = Color(0xFF1E1B4B);

  /// Warna folder card berurutan seperti web (ungu, biru, hijau, oranye).
  static const List<Color> folderColors = [purple, blue, green, orange];
}

class AppRadius {
  static const double card = 20.0;
  static const double panel = 20.0;
  static const double sheet = 28.0;
  static const double pill = 36.0;
  static const double input = 14.0;
  static const double chip = 14.0;
}

class AppShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get nav => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.20),
      blurRadius: 25,
      offset: const Offset(0, 10),
    ),
  ];
  static List<BoxShadow> get fab => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.20),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Dekorasi kartu standar: putih, radius 20, border abu, shadow lembut.
BoxDecoration cardDecoration({double radius = AppRadius.card}) {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border),
    boxShadow: AppShadows.soft,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.black,
    ),
  );

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
      .copyWith(
        // Judul besar (saldo utama): 32, extra-bold, letter-spacing -1.
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: AppColors.black,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.black,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.black,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.black,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.black,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.black),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
