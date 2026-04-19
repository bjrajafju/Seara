import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isChecking = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isChecking => _isChecking;

  Future<void> checkSession() async {
    _isChecking = true;
    notifyListeners();

    final isValid = await AuthService.validateSession();
    if (!isValid) {
      await AuthService.logout();
    }
    _isLoggedIn = isValid;
    _isChecking = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final error = await AuthService.login(email, password);
    if (error == null) {
      final isValid = await AuthService.validateSession();
      _isLoggedIn = isValid;
      if (!isValid) {
        await AuthService.logout();
        return 'Sessao invalida. Tente novamente.';
      }
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
    _isChecking = false;
    notifyListeners();
  }
}
