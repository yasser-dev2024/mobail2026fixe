import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightText,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme:
          _buildTextTheme(AppColors.lightText, AppColors.lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(
        AppColors.lightBorder,
        AppColors.lightText,
        AppColors.lightTextSecondary,
        AppColors.lightCard,
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightBorder,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      extensions: const [AppColorsExtension.light],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkText,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme:
          _buildTextTheme(AppColors.darkText, AppColors.darkTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(
        AppColors.darkBorder,
        AppColors.darkText,
        AppColors.darkTextSecondary,
        AppColors.darkCard,
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkBorder,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      extensions: const [AppColorsExtension.dark],
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.cairo(
          fontSize: 32, fontWeight: FontWeight.w700, color: primary),
      displayMedium: GoogleFonts.cairo(
          fontSize: 28, fontWeight: FontWeight.w700, color: primary),
      displaySmall: GoogleFonts.cairo(
          fontSize: 24, fontWeight: FontWeight.w600, color: primary),
      headlineLarge: GoogleFonts.cairo(
          fontSize: 22, fontWeight: FontWeight.w700, color: primary),
      headlineMedium: GoogleFonts.cairo(
          fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      headlineSmall: GoogleFonts.cairo(
          fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleLarge: GoogleFonts.cairo(
          fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleMedium: GoogleFonts.cairo(
          fontSize: 15, fontWeight: FontWeight.w500, color: primary),
      titleSmall: GoogleFonts.cairo(
          fontSize: 14, fontWeight: FontWeight.w500, color: secondary),
      bodyLarge: GoogleFonts.cairo(
          fontSize: 15, fontWeight: FontWeight.w400, color: primary),
      bodyMedium: GoogleFonts.cairo(
          fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      bodySmall: GoogleFonts.cairo(
          fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      labelLarge: GoogleFonts.cairo(
          fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.cairo(
          fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
      labelSmall: GoogleFonts.cairo(
          fontSize: 11, fontWeight: FontWeight.w400, color: secondary),
    );
  }

  static InputDecorationTheme _buildInputTheme(
      Color border, Color text, Color hint, Color fill) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: GoogleFonts.cairo(color: hint, fontSize: 14),
      hintStyle: GoogleFonts.cairo(color: hint, fontSize: 13),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  const AppColorsExtension({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });

  static const light = AppColorsExtension(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightText,
    textSecondary: AppColors.lightTextSecondary,
    divider: AppColors.lightDivider,
  );

  static const dark = AppColorsExtension(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkText,
    textSecondary: AppColors.darkTextSecondary,
    divider: AppColors.darkDivider,
  );

  @override
  AppColorsExtension copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
  }) {
    return AppColorsExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension ThemeContextExtension on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
