import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import 'profile_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  int? _myId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      _myId = await AuthService.getUserId();
      final users = await ProfileService.getAllUsers();
      setState(() {
        // Task 3: Filter out system user (id=0)
        _users = users.where((u) => u['id'] != 0).toList();
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Utilizadores")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      user['avatar'] ??
                          'https://ui-avatars.com/api/?name=${user['username']}',
                    ),
                  ),
                  title: Text(user['username']),
                  onTap: () {
                    // Task 1: Self -> my profile, other -> their profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => user['id'] == _myId
                            ? const ProfileScreen()
                            : ProfileScreen(userId: user['id']),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
