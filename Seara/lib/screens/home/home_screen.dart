import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seara/providers/auth_provider.dart';
import 'package:seara/providers/messages_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/user_list_screen.dart';
import '../settings/settings_screen.dart';
import '../challenges/challenges_screen.dart';
import '../feed/feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const int _logoutNavIndex = 6;

  final List<Widget> _pages = [
    FeedScreen(),
    MessagesScreen(),
    ChallengesScreen(),
    SettingsScreen(),
    ProfileScreen(),
    UserListScreen(),
  ];

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _loadToken();
  }

  /// Loads token
  void _loadToken() async {
    await AuthService.getToken();
  }

  /// Clears persisted session data and logs out the user
  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final messagesProvider = context.read<MessagesProvider>();

    messagesProvider.clear();
    await authProvider.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Seara')),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withAlpha(120),
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_rounded),
            label: 'Mensagens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on_rounded),
            label: 'Desafios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Definições',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Listar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout_rounded),
            label: 'Logout',
          ),
        ],
        onTap: (int index) async {
          if (index == _logoutNavIndex) {
            await _logout();
            return;
          }
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}
