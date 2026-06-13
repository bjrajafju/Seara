import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Base URL of the API.
  /// Use --dart-define=BASE_URL=http://your-url to override.
  static String get baseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Production URL (Render backend)
    const productionUrl = 'https://seara.onrender.com';

    // In Release mode, always use the production URL
    if (kReleaseMode) {
      return productionUrl;
    }

    // In Debug/Profile mode, we can have defaults for local development
    // For Web, we default to production to avoid localhost issues,
    // but you can override with --dart-define=BASE_URL=http://localhost:3000
    if (kIsWeb) {
      return productionUrl;
    }

    return productionUrl;
  }
}
