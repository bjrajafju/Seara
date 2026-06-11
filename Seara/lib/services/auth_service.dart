import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seara/config/api_config.dart';
import 'api_client.dart';
import 'auth_error_handler.dart';
import 'time_service.dart';

class AuthService {
  static String get baseUrl => '${ApiConfig.baseUrl}/auth';

  static Function(String)? onAuthError;

  static int _refreshFailures = 0;
  static bool _isRefreshing = false;
  static DateTime? _authBlockedUntil;
  static DateTime? _lastRefreshTime;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveSession(
    String accessToken,
    String? refreshToken,
  ) async {
    await _storage.write(key: 'access_token', value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
      try {
        await Supabase.instance.client.auth.setSession(refreshToken);
      } catch (e) {
        print("Warning: failed to set Supabase session: $e");
      }
    }
  }

  /// Reads the persisted refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  /// Reads the persisted auth token
  static Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  /// Persists the authenticated user id
  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: 'user_id', value: userId.toString());
  }

  /// Reads the persisted user id
  static Future<int?> getUserId() async {
    final val = await _storage.read(key: 'user_id');
    return val != null ? int.tryParse(val) : null;
  }

  /// Clears persisted session data and logs out the user
  static Future<void> logout({bool supabaseSignOut = true}) async {
    await _storage.deleteAll();
    if (supabaseSignOut) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
  }

  /// Manually refreshes the Supabase session with circuit breaker and concurrency protection
  static Future<bool> refreshSession() async {
    // Step 1: Strict lock - no waiting, just return if already in progress
    if (_isRefreshing) {
      if (kDebugMode) print("Auth: Refresh already in progress, skipping.");
      return true; 
    }

    // Debounce - ignore if last refresh was < 10 seconds ago
    if (_lastRefreshTime != null && 
        DateTime.now().difference(_lastRefreshTime!).inSeconds < 10) {
      if (kDebugMode) print("Auth: Refresh called too recently, skipping.");
      return true;
    }

    if (_authBlockedUntil != null && TimeService.now.isBefore(_authBlockedUntil!)) {
      if (kDebugMode) print("Auth: Circuit breaker active until $_authBlockedUntil");
      return false;
    }

    // System time sanity check
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.expiresAt != null) {
      final now = DateTime.now();
      final expiresAtSeconds = session.expiresAt!;
      
      // Inconsistent if expiresAt is suspiciously old (e.g., < year 2010) or far in the future
      bool isSuspicious = expiresAtSeconds < 1262304000 || 
                          expiresAtSeconds > (now.add(const Duration(days: 30)).millisecondsSinceEpoch / 1000);
      
      if (isSuspicious) {
        if (kDebugMode) print("Auth: Suspicious session expiry detected: $expiresAtSeconds. Likely invalid device time.");
        onAuthError?.call("Data/hora do dispositivo incorreta. Ajusta o relógio para continuar.");
        await logout();
        return false;
      }
    }

    _isRefreshing = true;
    _lastRefreshTime = DateTime.now();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        if (kDebugMode) print("Auth: No refresh token available.");
        return false;
      }

      if (kDebugMode) print("Auth: Attempting manual session refresh...");
      
      // Use setSession with refreshToken to trigger a manual refresh
      final response = await Supabase.instance.client.auth.setSession(refreshToken);
      
      if (response.session != null) {
        await saveSession(
          response.session!.accessToken,
          response.session!.refreshToken,
        );
        _refreshFailures = 0;
        if (kDebugMode) print("Auth: Manual refresh successful.");
        return true;
      }
      
      _refreshFailures++;
      return false;
    } on AuthException catch (e) {
      _refreshFailures++;
      if (kDebugMode) print("Auth: Refresh failed with AuthException: ${e.message} (Status: ${e.statusCode})");
      
      // Step 4 & 6: Hard stop on 429 or 2 consecutive failures
      if (e.statusCode == '429' || _refreshFailures >= 2) {
        _authBlockedUntil = TimeService.now.add(const Duration(minutes: 5));
        
        final errorMsg = e.statusCode == '429' 
          ? "Erro de autenticação (Too Many Requests). Verifica a data/hora do dispositivo e volta a iniciar sessão."
          : "Sessão expirada. Por favor, inicia sessão novamente.";
        
        onAuthError?.call(errorMsg);
        
        if (kDebugMode) print("Auth: Critical failure detected (429 or 2+ failures). Forcing logout.");
        await logout();
      }
      return false;
    } catch (e) {
      _refreshFailures++;
      if (kDebugMode) print("Auth: Refresh failed with unexpected error: $e");
      if (_refreshFailures >= 2) {
        await logout();
      }
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Validates the current auth token with the backend
  static Future<bool> validateSession() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/profile/me'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final refreshToken = await getRefreshToken();
        if (refreshToken != null) {
          try {
            await Supabase.instance.client.auth.setSession(refreshToken);
          } catch (e) {
            print("Warning: failed to restore Supabase session: $e");
          }
        }
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sends registration data and creates a new account
  static Future<String?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        return AuthErrorHandler.mapError(data['error'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      return AuthErrorHandler.mapError(e);
    }
  }

  /// Sends login credentials and stores the authenticated session
  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await saveSession(
          data['session']['access_token'],
          data['session']['refresh_token'],
        );

        await saveUserId(data['user']['id']);

        return null;
      } else {
        final data = jsonDecode(response.body);
        return AuthErrorHandler.mapError(data['error'] ?? 'Erro de login');
      }
    } catch (e) {
      return AuthErrorHandler.mapError(e);
    }
  }

  /// Updates the user's password
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // First, try to re-authenticate with Supabase to verify current password
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        try {
          final authResponse = await Supabase.instance.client.auth.signInWithPassword(
            email: currentUser.email!,
            password: currentPassword,
          );
          
          final session = authResponse.session;
          if (session != null) {
            await saveSession(
              session.accessToken,
              session.refreshToken,
            );
          }
        } catch (e) {
          return AuthErrorHandler.mapError(e);
        }
      }

      // Then update the password in Supabase
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        return 'Não foi possível alterar a password. Tenta novamente.';
      }

      // Optional: Notify backend if endpoint exists
      try {
        await ApiClient.post(
          Uri.parse('$baseUrl/change-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignore backend errors if Supabase update succeeded
      }

      return null;
    } catch (e) {
      return AuthErrorHandler.mapError(e);
    }
  }

  /// Sends a password reset email using Supabase
  static Future<String?> resetPassword(String email) async {
    try {
      String redirectTo;
      if (kIsWeb) {
        // Na Web, usamos o URL base atual
        redirectTo = Uri.base.origin;
      } else {
        // Em Desktop e Mobile, usamos o esquema customizado.
        redirectTo = 'seara://auth/recovery';
      }

      if (kDebugMode) {
        print("Requesting password reset for $email with redirectTo: $redirectTo");
      }

      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      return null;
    } catch (e) {
      return AuthErrorHandler.mapError(e);
    }
  }

  /// Updates the user's password using the recovery session
  static Future<String?> updatePassword(String newPassword) async {
    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (response.user == null) {
        return 'Não foi possível redefinir a password. Tenta novamente.';
      }
      return null;
    } catch (e) {
      return AuthErrorHandler.mapError(e);
    }
  }
}
