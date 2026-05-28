import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isChecking = true;
  bool _isRecovering = false;
  bool _recoveryHandled = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isChecking => _isChecking;
  bool get isRecovering => _isRecovering;
  bool get recoveryHandled => _recoveryHandled;

  void setRecovering(bool value) {
    _isRecovering = value;
    notifyListeners();
  }

  void setRecoveryHandled(bool value) {
    _recoveryHandled = value;
    notifyListeners();
  }

  AuthProvider() {
    _initSupabaseListener();
  }

  void _initSupabaseListener() {
    // Listen to Supabase auth changes to keep our provider in sync
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _isLoggedIn = true;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _isLoggedIn = false;
        notifyListeners();
      }
    });
  }

  /// Checks whether a valid session exists
  Future<void> checkSession() async {
    _isChecking = true;
    notifyListeners();

    final isValid = await AuthService.validateSession();
    if (!isValid) {
      // Don't call Supabase signOut during startup check to avoid invalidating 
      // an ongoing password recovery flow or other link-based auth.
      await AuthService.logout(supabaseSignOut: false);
    }
    _isLoggedIn = isValid;
    _isChecking = false;
    notifyListeners();
  }

  /// Sends login credentials and stores the authenticated session
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

  /// Login success
  Future<void> loginSuccess() async {
    _isLoggedIn = true;
    notifyListeners();
  }

  /// Clears persisted session data and logs out the user
  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    _isChecking = false;
    notifyListeners();
  }
}
