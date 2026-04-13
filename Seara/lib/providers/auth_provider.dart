import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isChecking = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isChecking => _isChecking;

  Future<void> checkSession() async {
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
    }
    _isChecking = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final error = await AuthService.login(email, password);
    if (error == null) {
      _isLoggedIn = true;
      notifyListeners();
    }
    return error;
  }

  Future<void> loginSuccess() async {
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    notifyListeners();
  }
}
