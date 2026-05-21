import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/profile/user_list_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/messages/messages_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'controllers/post_feed_controller.dart';
import 'controllers/story_feed_controller.dart';

/// Starts the app and wires top-level providers
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nzxmjazsegtsmsdqnisq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56eG1qYXpzZWd0c21zZHFuaXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwNjExMzMsImV4cCI6MjA3NDYzNzEzM30.kRJQfqNMJDK4RWxxMT2tcQYrugyesedxrX-V9Nq8_mU',
  );

  if (kIsWeb) {
    FilePicker.platform = FilePicker.platform;
  }

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final authProvider = AuthProvider();
  authProvider.addListener(() async {
    if (authProvider.isLoggedIn) {
      final userId = await AuthService.getUserId();
      await themeProvider.loadThemeForUser(userId);
    } else if (!authProvider.isLoggedIn && !authProvider.isChecking) {
      await themeProvider.loadThemeForUser(null);
    }
  });
  await authProvider.checkSession();

  runApp(SearaApp(themeProvider: themeProvider, authProvider: authProvider));
}

class SearaApp extends StatelessWidget {
  const SearaApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
  });

  final ThemeProvider themeProvider;
  final AuthProvider authProvider;

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => StoryFeedController()),
        ChangeNotifierProvider(create: (_) => PostFeedController()),
      ],

      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SEARA',
            themeMode: ThemeMode.light,
            theme: theme.currentTheme,
            home: auth.isChecking
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : auth.isLoggedIn
                ? const HomeScreen()
                : const LoginScreen(),
            routes: {
              '/home': (ctx) => const HomeScreen(),
              '/profile': (ctx) => const ProfileScreen(),
              '/settings': (ctx) => const SettingsScreen(),
              '/list': (ctx) => const UserListScreen(),
              '/messages': (ctx) => const MessagesScreen(),
            },
          );
        },
      ),
    );
  }
}
