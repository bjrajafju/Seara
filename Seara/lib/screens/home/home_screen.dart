import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _token = '';
  int _selectedIndex = 0;

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
      body: Container(
        color: Color.fromARGB(255, 255, 153, 0),
        child: Text("Centro da app"),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, //tem de ser fixed para a cor dar idfk
        backgroundColor: Color.fromARGB(255, 67, 17, 38), 
        selectedItemColor: Color.fromARGB(255, 255, 0, 0),
        unselectedItemColor: Color.fromARGB(222, 149, 211, 247),
        currentIndex: 0, //pagina atual
        items: [ //cena com os butoes em baixo
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "home"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "messages"),
          BottomNavigationBarItem(
            icon: Icon(Icons.thunderstorm),
            label: "desafios",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "definições",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "perfil"),
        ],
        onTap: (valor) {
          print(valor);
        },
      ),
    );
  }
}
