import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  runApp(const SearaApp());
}

class SearaApp extends StatelessWidget {
  const SearaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SEARA',
            themeMode: theme.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            //home: auth.isLoggedIn ? HomeScreen() : LoginScreen(),
            home: HomeScreen(),
            
            routes: {
              //'/': (ctx) => const LoginScreen(), // se necessário
              '/home': (ctx) => const HomeScreen(),
              //'/profile': (ctx) => const ProfileScreen(),
              '/settings': (ctx) => const SettingsScreen(),
              //'/followers': (ctx) => const FollowersScreen(), // cria placeholder se precisares
              //'/following': (ctx) => const FollowingScreen(),
            },
          );
        },
      ),
    );
  }
}
