import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seara/config/api_config.dart';
import 'api_client.dart';
import 'auth_error_handler.dart';

class AuthService {
  static String get baseUrl => '${ApiConfig.baseUrl}/auth';

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
        // Na Web, usamos o URL base atual (ex: http://localhost:59160)
        // para garantir que volta para a mesma porta/ambiente.
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
