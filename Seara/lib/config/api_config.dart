import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Defaults:
  /// - Web: http://localhost:3000
  /// - Android emulator: http://10.0.2.2:3000
  /// - iOS simulator: http://localhost:3000
  /// - Desktop (Windows/macOS/Linux): http://localhost:3000
  //
  /// Override for real devices (or any custom environment):
  /// flutter run --dart-define=BASE_URL=http://192.168.X.X:3000
  static String get baseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    if (kIsWeb) {
      return 'https://seara.onrender.com';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';

      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 'http://localhost:3000';

      default:
        throw UnsupportedError('Unsupported platform for API base URL.');
    }
  }
}
