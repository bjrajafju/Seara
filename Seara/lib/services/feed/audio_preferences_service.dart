import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the global mute preference for story video playback.
///
/// - On Web: defaults to muted (browser autoplay policy).
/// - On all other platforms: defaults to unmuted.
/// - Persists across app sessions via SharedPreferences.
class AudioPreferencesService {
  static const _key = 'story_muted';

  /// Returns the stored mute preference.
  /// Falls back to [true] on Web, [false] on native.
  static Future<bool> isMuted() async {
    final prefs = await SharedPreferences.getInstance();
    // If no value is stored yet, apply platform default.
    if (!prefs.containsKey(_key)) {
      return kIsWeb; // web = muted by default
    }
    return prefs.getBool(_key) ?? kIsWeb;
  }

  /// Persists the mute preference.
  static Future<void> setMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, muted);
  }
}
