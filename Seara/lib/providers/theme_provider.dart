import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/user_repository.dart';

//// To add a new theme:
////  1. Add a new value here.
////  2. Add a matching ThemeData getter in [AppTheme].
////  3. Register it in [ThemeProvider.themes].

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
  final UserRepository _userRepository;

  ThemeProvider({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  AppThemeId get activeId => _activeId;

  ThemeData get currentTheme => themes[_activeId] ?? AppTheme.dark;

  AppThemeId get _defaultTheme {
    try {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark ? AppThemeId.dark : AppThemeId.light;
    } catch (_) {
      return AppThemeId.dark;
    }
  }

  /// Initializes local dependencies and startup state
  Future<void> init() async {
    await loadThemeForCurrentUser();
  }

  /// Loads the theme for the currently authenticated user
  Future<void> loadThemeForCurrentUser() async {
    await loadThemeForUser(_userRepository.currentAuthId);
  }

  /// Loads the theme for a specific user ID, or defaults to system theme
  Future<void> loadThemeForUser(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    AppThemeId targetId = _defaultTheme;

    // 1. Try to get from database first if user is logged in
    if (userId != null) {
      final dbTheme = await _userRepository.getUserTheme(userId);
      if (dbTheme != null) {
        targetId = _parseThemeId(dbTheme);
        // Sync to local cache
        await prefs.setString('${_prefKey}_$userId', targetId.name);
      } else {
        // 2. Fallback to local cache if DB fails or is empty
        final key = '${_prefKey}_$userId';
        final saved = prefs.getString(key);
        if (saved != null) {
          targetId = _parseThemeId(saved);
        }
      }
    } else {
      // Not logged in, use global local cache
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        targetId = _parseThemeId(saved);
      }
    }

    if (_activeId != targetId) {
      _activeId = targetId;
      notifyListeners();
    }
  }

  AppThemeId _parseThemeId(String name) {
    return AppThemeId.values.firstWhere(
      (e) => e.name == name,
      orElse: () => _defaultTheme,
    );
  }

  /// Set theme
  Future<void> setTheme(AppThemeId id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    final authId = _userRepository.currentAuthId;
    
    if (authId != null) {
      // Update DB (async)
      _userRepository.setUserTheme(authId, id.name);
      // Update local cache
      await prefs.setString('${_prefKey}_$authId', id.name);
    } else {
      await prefs.setString(_prefKey, id.name);
    }
  }
}
