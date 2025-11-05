import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard/dashboard_screen.dart';

// Color palette
class AppColors {
  static const Color main = Color(0xFFFF3F00); // rgb(255, 63, 0)
  static const Color accent = Color(0xFF1D4ED8); // rgb(29, 78, 216)
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF9FAFB);
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BP Mobile',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppColors.main,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
          onError: Colors.white,
        ),
        textTheme:
            GoogleFonts.bricolageGrotesqueTextTheme(
              ThemeData.light().textTheme,
            ).apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.main,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.bricolageGrotesque(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.main,
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.bricolageGrotesque(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: AppColors.surface,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
