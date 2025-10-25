import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _token = '';

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
      appBar: AppBar(title: Text('Home')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Token JWT:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            SelectableText(_token),
            SizedBox(height: 30),
            ElevatedButton(onPressed: _logout, child: Text('Logout')),
          ],
        ),
      ),
    );
  }
}
