import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seara/config/api_config.dart';
import 'api_client.dart';

class AuthService {
  static String get baseUrl => '${ApiConfig.baseUrl}/auth';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveSession(
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    try {
      await Supabase.instance.client.auth.setSession(refreshToken);
    } catch (e) {
      print("Warning: failed to set Supabase session: $e");
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
  static Future<void> logout() async {
    await _storage.deleteAll();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
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
        return data['error'] ?? 'Erro desconhecido';
      }
    } catch (e) {
      return 'Erro de conexão: $e';
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

        try {
          await Supabase.instance.client.auth.setSession(
            data['session']['refresh_token'],
          );
        } catch (e) {
          print("Warning: failed to set Supabase session in login: $e");
        }

        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Erro de login';
      }
    } catch (e) {
      return 'Erro de conexão: $e';
    }
  }
}
