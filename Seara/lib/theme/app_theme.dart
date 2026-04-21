import 'package:flutter/material.dart';

//// To add a new theme:
////  1. Define a static ThemeData getter here.
////  2. Add a new value to [AppThemeId] in theme_provider.dart.
////  3. Register it in [ThemeProvider.themes].

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF6750A4),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF625B71),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF7F2FA),
      onSurface: Color(0xFF1C1B1F),
      surfaceContainerHighest: Color(0xFFE7E0EC),
      onSurfaceVariant: Color(0xFF49454F),
    );
    return _buildTheme(cs);
  }

  static ThemeData get dark {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFD0BCFF),
      onPrimary: Color(0xFF381E72),
      secondary: Color(0xFFCCC2DC),
      onSecondary: Color(0xFF332D41),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: Color(0xFF1C1B1F),
      onSurface: Color(0xFFE6E1E5),
      surfaceContainerHighest: Color(0xFF49454F),
      onSurfaceVariant: Color(0xFFCAC4D0),
    );
    return _buildTheme(cs);
  }

  static ThemeData get highContrast {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF21005D),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF1D192B),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFF8C0009),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF000000),
      surfaceContainerHighest: Color(0xFFE0E0E0),
      onSurfaceVariant: Color(0xFF000000),
    );
    return _buildTheme(cs);
  }

  static ThemeData get amoled {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF9F8FFF),
      onPrimary: Color(0xFF1A0055),
      secondary: Color(0xFF7B6FA8),
      onSecondary: Color(0xFF000000),
      error: Color(0xFFFF6B6B),
      onError: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFEEEEEE),
      surfaceContainerHighest: Color(0xFF1A1A1A),
      onSurfaceVariant: Color(0xFFAAAAAA),
    );
    return _buildTheme(cs);
  }

  static ThemeData get ocean {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF4FC3F7),
      onPrimary: Color(0xFF003A52),
      secondary: Color(0xFF81D4FA),
      onSecondary: Color(0xFF002B3D),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF690005),
      surface: Color(0xFF0D1B2A),
      onSurface: Color(0xFFDEF0FF),
      surfaceContainerHighest: Color(0xFF1B3A4B),
      onSurfaceVariant: Color(0xFF90CAF9),
    );
    return _buildTheme(cs);
  }

  static ThemeData get sunset {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFAB40),
      onPrimary: Color(0xFF3D1C00),
      secondary: Color(0xFFCE93D8),
      onSecondary: Color(0xFF2D0040),
      error: Color(0xFFFF6E6E),
      onError: Color(0xFF410001),
      surface: Color(0xFF1A0A00),
      onSurface: Color(0xFFFFECDB),
      surfaceContainerHighest: Color(0xFF3A1800),
      onSurfaceVariant: Color(0xFFFFCC80),
    );
    return _buildTheme(cs);
  }

  static ThemeData get forest {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF69BB7F),
      onPrimary: Color(0xFF003914),
      secondary: Color(0xFFA5D6A7),
      onSecondary: Color(0xFF002106),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF690005),
      surface: Color(0xFF0B1F12),
      onSurface: Color(0xFFDCF5DC),
      surfaceContainerHighest: Color(0xFF1B3A25),
      onSurfaceVariant: Color(0xFF81C784),
    );
    return _buildTheme(cs);
  }

  static ThemeData get midnight {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7986CB),
      onPrimary: Color(0xFF0A0E3F),
      secondary: Color(0xFF5C6BC0),
      onSecondary: Color(0xFF050820),
      error: Color(0xFFEF9A9A),
      onError: Color(0xFF410001),
      surface: Color(0xFF070B1A),
      onSurface: Color(0xFFE3E6FF),
      surfaceContainerHighest: Color(0xFF151A35),
      onSurfaceVariant: Color(0xFF9FA8DA),
    );
    return _buildTheme(cs);
  }

  static ThemeData get rose {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFAD1457),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF880E4F),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFF0F5),
      onSurface: Color(0xFF3B0024),
      surfaceContainerHighest: Color(0xFFFCCEDE),
      onSurfaceVariant: Color(0xFF6A0032),
    );
    return _buildTheme(cs);
  }

  static ThemeData get amber {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFF59F00),
      onPrimary: Color(0xFF3D2000),
      secondary: Color(0xFFE67700),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFBF0),
      onSurface: Color(0xFF2C1A00),
      surfaceContainerHighest: Color(0xFFFFE8A1),
      onSurfaceVariant: Color(0xFF5A3700),
    );
    return _buildTheme(cs);
  }

  static ThemeData get nord {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF88C0D0),
      onPrimary: Color(0xFF2E3440),
      secondary: Color(0xFF81A1C1),
      onSecondary: Color(0xFF2E3440),
      error: Color(0xFFBF616A),
      onError: Color(0xFFECEFF4),
      surface: Color(0xFF2E3440),
      onSurface: Color(0xFFECEFF4),
      surfaceContainerHighest: Color(0xFF3B4252),
      onSurfaceVariant: Color(0xFFD8DEE9),
    );
    return _buildTheme(cs);
  }

  static ThemeData get dracula {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFBD93F9),
      onPrimary: Color(0xFF1A0050),
      secondary: Color(0xFF50FA7B),
      onSecondary: Color(0xFF003310),
      error: Color(0xFFFF5555),
      onError: Color(0xFF000000),
      surface: Color(0xFF282A36),
      onSurface: Color(0xFFF8F8F2),
      surfaceContainerHighest: Color(0xFF44475A),
      onSurfaceVariant: Color(0xFF6272A4),
    );
    return _buildTheme(cs);
  }

  static ThemeData get mocha {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFCBA6F7),
      onPrimary: Color(0xFF1E1E2E),
      secondary: Color(0xFFF5C2E7),
      onSecondary: Color(0xFF1E1E2E),
      error: Color(0xFFF38BA8),
      onError: Color(0xFF1E1E2E),
      surface: Color(0xFF1E1E2E),
      onSurface: Color(0xFFCDD6F4),
      surfaceContainerHighest: Color(0xFF313244),
      onSurfaceVariant: Color(0xFFBAC2DE),
    );
    return _buildTheme(cs);
  }

  static ThemeData get arctic {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0277BD),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF006064),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF0F8FF),
      onSurface: Color(0xFF002B49),
      surfaceContainerHighest: Color(0xFFB3E5FC),
      onSurfaceVariant: Color(0xFF01579B),
    );
    return _buildTheme(cs);
  }

  static ThemeData get sakura {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFE91E8C),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF9C27B0),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFF5F9),
      onSurface: Color(0xFF3A0020),
      surfaceContainerHighest: Color(0xFFFFCCE8),
      onSurfaceVariant: Color(0xFF7A0045),
    );
    return _buildTheme(cs);
  }

  static ThemeData get slate {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF94A3B8),
      onPrimary: Color(0xFF0F172A),
      secondary: Color(0xFF64748B),
      onSecondary: Color(0xFF0F172A),
      error: Color(0xFFF87171),
      onError: Color(0xFF000000),
      surface: Color(0xFF0F172A),
      onSurface: Color(0xFFE2E8F0),
      surfaceContainerHighest: Color(0xFF1E293B),
      onSurfaceVariant: Color(0xFF94A3B8),
    );
    return _buildTheme(cs);
  }

  /// Builds and returns the app theme configuration
  static ThemeData _buildTheme(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        shadowColor: cs.onSurface.withAlpha(30),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
        actionsIconTheme: IconThemeData(color: cs.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withAlpha(
          cs.brightness == Brightness.dark ? 80 : 120,
        ),
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(160)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withAlpha(80)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cs.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        selectedColor: cs.primary.withAlpha(40),
        checkmarkColor: cs.primary,
        side: BorderSide(color: cs.outline.withAlpha(80)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: cs.onSurface.withAlpha(25),
        thickness: 0.5,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        textColor: cs.onSurface,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
