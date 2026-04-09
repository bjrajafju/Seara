import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Identifies an available theme.
///
/// To add a new theme:
///   1. Add a new value here.
///   2. Add a matching ThemeData getter in [AppTheme].
///   3. Register it in [ThemeProvider.themes].
enum AppThemeId {
  light,
  dark,
  highContrast,
}

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'seara_theme_id';

  /// Registry of all available themes. Add new entries here to expose them.
  static final Map<AppThemeId, ThemeData> themes = {
    AppThemeId.light: AppTheme.light,
    AppThemeId.dark: AppTheme.dark,
    AppThemeId.highContrast: AppTheme.highContrast,
  };

  /// Human-readable labels for each theme (used in Settings UI).
  static const Map<AppThemeId, String> labels = {
    AppThemeId.light: 'Claro',
    AppThemeId.dark: 'Escuro',
    AppThemeId.highContrast: 'Alto Contraste',
  };

  /// Icons for each theme (used in Settings UI).
  static const Map<AppThemeId, IconData> icons = {
    AppThemeId.light: Icons.light_mode_rounded,
    AppThemeId.dark: Icons.dark_mode_rounded,
    AppThemeId.highContrast: Icons.contrast_rounded,
  };

  AppThemeId _activeId = AppThemeId.dark;

  AppThemeId get activeId => _activeId;

  ThemeData get currentTheme => themes[_activeId] ?? AppTheme.dark;

  /// Call once at startup (inside ChangeNotifierProvider create callback).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _activeId = AppThemeId.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeId.dark,
      );
      notifyListeners();
    }
  }

  /// Switch to [id] and persist the selection.
  Future<void> setTheme(AppThemeId id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id.name);
  }
}
