import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
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

  final List<Widget> _pages = [
    FeedScreen(),
    MessagesScreen(),
    ChallengesScreen(),
    SettingsScreen(),
    ProfileScreen(),
    UserListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  void _loadToken() async {
    await AuthService.getToken();
  }

  @override
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
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Mensagens'),
          BottomNavigationBarItem(icon: Icon(Icons.flash_on_rounded), label: 'Desafios'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Definições'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Listar'),
        ],
        onTap: (int index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
