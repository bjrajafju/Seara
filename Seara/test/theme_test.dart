import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seara/providers/theme_provider.dart';
import 'package:seara/services/user_repository.dart';

class MockUserRepository extends UserRepository {
  final Map<String, String> _themes = {};
  String? _currentUserId;

  @override
  String? get currentAuthId => _currentUserId;

  void setMockUserId(String? id) => _currentUserId = id;

  @override
  Future<String?> getUserTheme(String authId) async {
    return _themes[authId];
  }

  @override
  Future<void> setUserTheme(String authId, String theme) async {
    _themes[authId] = theme;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> secureStorageData = {};

  setUp(() {
    secureStorageData.clear();
    // Mock flutter_secure_storage platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') {
          return secureStorageData[methodCall.arguments['key']];
        }
        if (methodCall.method == 'write') {
          secureStorageData[methodCall.arguments['key']] = methodCall.arguments['value'];
          return true;
        }
        if (methodCall.method == 'deleteAll') {
          secureStorageData.clear();
          return true;
        }
        return null;
      },
    );
  });

  test('ThemeProvider isolates themes per user and falls back to default', () async {
    // 1. Setup mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    final mockRepo = MockUserRepository();
    final provider = ThemeProvider(userRepository: mockRepo);

    // Default theme check
    expect(provider.activeId, AppThemeId.dark);

    // 2. Load theme for null user (should fall back to default/system theme)
    // Test dark system theme fallback
    TestWidgetsFlutterBinding.instance.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await provider.loadThemeForUser(null);
    expect(provider.activeId, AppThemeId.dark);

    // Test light system theme fallback
    TestWidgetsFlutterBinding.instance.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await provider.loadThemeForUser(null);
    expect(provider.activeId, AppThemeId.light);

    // Reset brightness to dark for remaining steps
    TestWidgetsFlutterBinding.instance.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await provider.loadThemeForUser(null);

    // 3. User A logs in (userId = '123')
    // By default, they should have default theme since no preference is saved
    mockRepo.setMockUserId('123');
    await provider.loadThemeForUser('123');
    expect(provider.activeId, AppThemeId.dark);

    // Set User A's theme to Ocean and save it
    secureStorageData['user_id'] = '123';
    await provider.setTheme(AppThemeId.ocean);
    expect(provider.activeId, AppThemeId.ocean);

    // 4. Logout User A (userId = null)
    secureStorageData.remove('user_id');
    mockRepo.setMockUserId(null);
    await provider.loadThemeForUser(null);
    expect(provider.activeId, AppThemeId.dark); // Reverts to fallback

    // 5. User B logs in (userId = '456')
    mockRepo.setMockUserId('456');
    await provider.loadThemeForUser('456');
    expect(provider.activeId, AppThemeId.dark); // Starts with fallback

    // Set User B's theme to Sakura
    secureStorageData['user_id'] = '456';
    await provider.setTheme(AppThemeId.sakura);
    expect(provider.activeId, AppThemeId.sakura);

    // 6. Switch back to User A
    secureStorageData['user_id'] = '123';
    mockRepo.setMockUserId('123');
    await provider.loadThemeForUser('123');
    expect(provider.activeId, AppThemeId.ocean); // User A's theme is restored!

    // 7. Switch back to User B
    secureStorageData['user_id'] = '456';
    mockRepo.setMockUserId('456');
    await provider.loadThemeForUser('456');
    expect(provider.activeId, AppThemeId.sakura); // User B's theme is restored!

    // 8. Logout User B
    secureStorageData.remove('user_id');
    mockRepo.setMockUserId(null);
    await provider.loadThemeForUser(null);
    expect(provider.activeId, AppThemeId.dark); // Reverts back to fallback
  });
}
