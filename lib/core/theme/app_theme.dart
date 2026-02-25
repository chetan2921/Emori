import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// ─── Brand Colors (same in both modes) ───────────────────────────

class AppColors {
  AppColors._();

  static const primary = Color(0xFF243D1D);
  static const primaryDark = Color(0xFF1A2D15);
  static const olive = Color(0xFFB4B56D);
  static const sage = Color(0xFFDEE2B0);
  static const teal = Color(0xFF8DB2A2);
  static const coral = Color(0xFFE4704B);
  static const accent = coral;
  static const success = Color(0xFF4A8B6E);
  static const error = Color(0xFFD9534F);

  static Color lifeArea(String area) {
    final map = {
      'career': const Color(0xFF243D1D),
      'relationships': const Color(0xFFE4704B),
      'health': const Color(0xFF8DB2A2),
      'money': const Color(0xFFB4B56D),
      'identity': const Color(0xFF6B8F71),
      'growth': const Color(0xFF4A8B6E),
    };
    return map[area.toLowerCase()] ?? const Color(0xFF9CA89E);
  }

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF3A5C30)],
  );

  static const coralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, Color(0xFFE8916E)],
  );
}

// ─── Shadows ─────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static BoxShadow get card => BoxShadow(
    color: AppColors.primary.withValues(alpha: 0.06),
    blurRadius: 20,
    offset: const Offset(0, 6),
  );

  static BoxShadow get subtle => BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );

  static BoxShadow colored(Color color) => BoxShadow(
    color: color.withValues(alpha: 0.2),
    blurRadius: 16,
    offset: const Offset(0, 5),
  );
}

// ─── Nav bar clearance ───────────────────────────────────────────

const kNavBarClearance = 76.0;

// ─── Dynamic Colors (light / dark) ──────────────────────────────

@immutable
class EmoriColors extends ThemeExtension<EmoriColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primarySurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color border;
  final Color divider;

  const EmoriColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primarySurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.divider,
  });

  static const light = EmoriColors(
    background: Color(0xFFF7F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF2F0EA),
    primarySurface: Color(0xFFE8ECE0),
    textPrimary: Color(0xFF1E2D1A),
    textSecondary: Color(0xFF5C6B5E),
    textHint: Color(0xFF9CA89E),
    border: Color(0xFFE8E5DF),
    divider: Color(0xFFDBD8D2),
  );

  static const dark = EmoriColors(
    background: Color(0xFF121110),
    surface: Color(0xFF1C1B18),
    surfaceVariant: Color(0xFF252420),
    primarySurface: Color(0xFF1A2E15),
    textPrimary: Color(0xFFE8E5DF),
    textSecondary: Color(0xFFA0A09A),
    textHint: Color(0xFF6B6B65),
    border: Color(0xFF2E2D28),
    divider: Color(0xFF3A3935),
  );

  @override
  EmoriColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? primarySurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? border,
    Color? divider,
  }) {
    return EmoriColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      primarySurface: primarySurface ?? this.primarySurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      border: border ?? this.border,
      divider: divider ?? this.divider,
    );
  }

  @override
  EmoriColors lerp(covariant EmoriColors? other, double t) {
    if (other == null) return this;
    return EmoriColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

/// Convenience extension — use `context.colors.surface` etc.
extension EmoriColorsX on BuildContext {
  EmoriColors get colors => Theme.of(this).extension<EmoriColors>()!;
}

// ─── Themes ──────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: EmoriColors.light.surface,
      ),
      scaffoldBackgroundColor: EmoriColors.light.background,
      textTheme: _textTheme(EmoriColors.light),
      extensions: const [EmoriColors.light],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        surface: EmoriColors.dark.surface,
      ),
      scaffoldBackgroundColor: EmoriColors.dark.background,
      textTheme: _textTheme(EmoriColors.dark),
      extensions: const [EmoriColors.dark],
    );
  }

  static TextTheme _textTheme(EmoriColors c) => TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
      letterSpacing: -0.5,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Nunito',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: c.textPrimary,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Nunito',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: c.textSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Nunito',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: c.textHint,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Nunito',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: c.textHint,
      letterSpacing: 0.8,
    ),
  );
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle emoriTitle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: 'AlexBrush',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
    );
  }
}
