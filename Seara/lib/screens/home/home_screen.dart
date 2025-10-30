import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../challenges/challenges_screen.dart';
import '../feed/feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _token = '';
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    FeedScreen(),
    MessagesScreen(),
    ChallengesScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  void _loadToken() async {
    final token = await AuthService.getToken();
    setState(() {
      _token = token ?? 'Nenhum token encontrado';
    });
  }

  void _logout() async {
    await AuthService.logout();
    setState(() {
      _token = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Seara')),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 67, 17, 38),
        selectedItemColor: const Color.fromARGB(255, 255, 0, 0),
        unselectedItemColor: const Color.fromARGB(222, 149, 211, 247),
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: "Mensagens",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: "Desafios",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Definições",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
