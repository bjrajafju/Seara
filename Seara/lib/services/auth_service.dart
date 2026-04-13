import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl =
      'http://localhost:3000/auth'; // mudar dependendo do disposivito

  static const _storage = FlutterSecureStorage(
     aOptions: AndroidOptions(encryptedSharedPreferences: true)
  );

  // Guarda tokens localmente
  static Future<void> saveSession(
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  // Carrega token
  static Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  // Guarda userId localmente
  static Future<void> saveUserId(int userId) async {
    await _storage.write(key: 'user_id', value: userId.toString());
  }

  // Lê userId
  static Future<int?> getUserId() async {
    final val = await _storage.read(key: 'user_id');
    return val != null ? int.tryParse(val) : null;
  }

  // Logout
  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  // REGISTER
  static Future<String?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return null; // sucesso
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Erro desconhecido';
      }
    } catch (e) {
      return 'Erro de conexão: $e';
    }
  }

  // LOGIN
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

        // ESTE é o ID correto
        await saveUserId(data['user']['id']);

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
