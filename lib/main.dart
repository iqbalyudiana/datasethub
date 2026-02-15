import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'feature_selection_screen.dart';
import 'services/localization_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalizationService.localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Dataset Hub',
          theme: _buildTheme(),
          home: const FeatureSelectionScreen(),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('id')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }

  ThemeData _buildTheme() {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00695C), // Deep Teal
        brightness: Brightness.light,
        surface: const Color(0xFFF5F7FA), // Light Grey-Blue background
        surfaceTint: Colors.white,
      ),
      useMaterial3: true,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(
          textStyle: baseTextTheme.displayLarge,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.poppins(
          textStyle: baseTextTheme.displayMedium,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.poppins(
          textStyle: baseTextTheme.displaySmall,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.poppins(
          textStyle: baseTextTheme.headlineLarge,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.poppins(
          textStyle: baseTextTheme.headlineMedium,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.poppins(
          textStyle: baseTextTheme.titleLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: const Color(0xFF1A1C1E),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1C1E)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF00695C), width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
        labelStyle: GoogleFonts.inter(color: Colors.grey[700]),
        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
      ),
    );
  }
}
