import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isChecking = true;
  bool _isRecovering = false;
  bool _recoveryHandled = false;
  String? _authErrorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isChecking => _isChecking;
  bool get isRecovering => _isRecovering;
  bool get recoveryHandled => _recoveryHandled;
  String? get authErrorMessage => _authErrorMessage;

  void clearAuthError() {
    _authErrorMessage = null;
    notifyListeners();
  }

  void setRecovering(bool value) {
    _isRecovering = value;
    notifyListeners();
  }

  void setRecoveryHandled(bool value) {
    _recoveryHandled = value;
    notifyListeners();
  }

  DateTime? _lastRefreshEventTime;

  AuthProvider() {
    _initSupabaseListener();
    _initAuthServiceListener();
  }

  void _initAuthServiceListener() {
    AuthService.onAuthError = (msg) {
      _authErrorMessage = msg;
      _isLoggedIn = false;
      _isChecking = false;
      notifyListeners();
    };
  }

  void _initSupabaseListener() {
    // Listen to Supabase auth changes to keep our provider in sync
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (kDebugMode) {
        print("Auth: Supabase event detected: $event");
      }

      // Debounce tokenRefreshed events
      if (event == AuthChangeEvent.tokenRefreshed) {
        if (_lastRefreshEventTime != null && 
            DateTime.now().difference(_lastRefreshEventTime!).inSeconds < 10) {
          if (kDebugMode) print("Auth: Ignoring repeated tokenRefreshed event (debounce).");
          return;
        }
        _lastRefreshEventTime = DateTime.now();
      }

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _isLoggedIn = true;

        // Handle recovery state cleanup
        final bool isRecoveryInUrl = kIsWeb &&
            (Uri.base.fragment.contains('type=recovery') ||
                Uri.base.queryParameters.containsKey('code'));
        if (isRecoveryInUrl || event == AuthChangeEvent.passwordRecovery) {
          _isRecovering = false;
        }

        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _isLoggedIn = false;
        notifyListeners();
      } else if (event != AuthChangeEvent.initialSession) {
        // Generic cleanup for other events if not in recovery URL
        final bool isRecoveryInUrl = kIsWeb &&
            (Uri.base.fragment.contains('type=recovery') ||
                Uri.base.queryParameters.containsKey('code'));
        if (!isRecoveryInUrl) {
          _isRecovering = false;
          notifyListeners();
        }
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
