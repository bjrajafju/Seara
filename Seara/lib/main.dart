import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/profile/user_list_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/messages/messages_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nzxmjazsegtsmsdqnisq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56eG1qYXpzZWd0c21zZHFuaXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwNjExMzMsImV4cCI6MjA3NDYzNzEzM30.kRJQfqNMJDK4RWxxMT2tcQYrugyesedxrX-V9Nq8_mU',
  );

  if (kIsWeb) {
    FilePicker.platform = FilePicker.platform;
  }

  // Load persisted theme before painting the first frame.
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(SearaApp(themeProvider: themeProvider));
}

class SearaApp extends StatelessWidget {
  const SearaApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Reuse the already-initialised instance so there's no flicker.
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SEARA',
            // ThemeMode.light is intentional: we bypass Flutter's light/dark
            // switch and always inject the full ThemeData directly. This
            // enables unlimited custom themes with no API constraint.
            themeMode: ThemeMode.light,
            theme: theme.currentTheme,
            home: auth.isLoggedIn ? HomeScreen() : LoginScreen(),
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
