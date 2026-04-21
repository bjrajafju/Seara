import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// To add a new theme:
///  1. Add a new value here.
///  2. Add a matching ThemeData getter in [AppTheme].
///  3. Register it in [ThemeProvider.themes].

enum AppThemeId {
  light,
  dark,
  highContrast,
  amoled,
  ocean,
  sunset,
  forest,
  midnight,
  rose,
  amber,
  nord,
  dracula,
  mocha,
  arctic,
  sakura,
  slate,
}

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'seara_theme_id';

  static final Map<AppThemeId, ThemeData> themes = {
    AppThemeId.light: AppTheme.light,
    AppThemeId.dark: AppTheme.dark,
    AppThemeId.highContrast: AppTheme.highContrast,
    AppThemeId.amoled: AppTheme.amoled,
    AppThemeId.ocean: AppTheme.ocean,
    AppThemeId.sunset: AppTheme.sunset,
    AppThemeId.forest: AppTheme.forest,
    AppThemeId.midnight: AppTheme.midnight,
    AppThemeId.rose: AppTheme.rose,
    AppThemeId.amber: AppTheme.amber,
    AppThemeId.nord: AppTheme.nord,
    AppThemeId.dracula: AppTheme.dracula,
    AppThemeId.mocha: AppTheme.mocha,
    AppThemeId.arctic: AppTheme.arctic,
    AppThemeId.sakura: AppTheme.sakura,
    AppThemeId.slate: AppTheme.slate,
  };

  static const Map<AppThemeId, String> labels = {
    AppThemeId.light: 'Claro',
    AppThemeId.dark: 'Escuro',
    AppThemeId.highContrast: 'Alto Contraste',
    AppThemeId.amoled: 'AMOLED',
    AppThemeId.ocean: 'Oceano',
    AppThemeId.sunset: 'Por do Sol',
    AppThemeId.forest: 'Floresta',
    AppThemeId.midnight: 'Meia-noite',
    AppThemeId.rose: 'Rosa',
    AppThemeId.amber: 'Ambar',
    AppThemeId.nord: 'Nord',
    AppThemeId.dracula: 'Dracula',
    AppThemeId.mocha: 'Mocha',
    AppThemeId.arctic: 'Artico',
    AppThemeId.sakura: 'Sakura',
    AppThemeId.slate: 'Ardosia',
  };

  static const Map<AppThemeId, IconData> icons = {
    AppThemeId.light: Icons.light_mode_rounded,
    AppThemeId.dark: Icons.dark_mode_rounded,
    AppThemeId.highContrast: Icons.contrast_rounded,
    AppThemeId.amoled: Icons.phone_android_rounded,
    AppThemeId.ocean: Icons.water_rounded,
    AppThemeId.sunset: Icons.wb_twilight_rounded,
    AppThemeId.forest: Icons.forest_rounded,
    AppThemeId.midnight: Icons.nightlight_rounded,
    AppThemeId.rose: Icons.favorite_rounded,
    AppThemeId.amber: Icons.wb_sunny_rounded,
    AppThemeId.nord: Icons.ac_unit_rounded,
    AppThemeId.dracula: Icons.dark_mode_rounded,
    AppThemeId.mocha: Icons.coffee_rounded,
    AppThemeId.arctic: Icons.severe_cold_rounded,
    AppThemeId.sakura: Icons.local_florist_rounded,
    AppThemeId.slate: Icons.layers_rounded,
  };

  AppThemeId _activeId = AppThemeId.dark;

  AppThemeId get activeId => _activeId;

  ThemeData get currentTheme => themes[_activeId] ?? AppTheme.dark;

  // Initializes local dependencies and startup state
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

  // Set theme
  Future<void> setTheme(AppThemeId id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id.name);
  }
}
