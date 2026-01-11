import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seara/models/profile_model.dart';

class ProfileService {
  static const String baseUrl = 'http://localhost:3000';

  static Future<Profile> getProfile(int userId) async {
    final url = Uri.parse('$baseUrl/profile/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Profile.fromJson(data);
    } else {
      throw Exception('Erro ao carregar perfil');
    }
  }

  static Future<void> updateProfile({
    required int userId,
    required String name,
    required String username,
    required String bio,
    required String avatar,
  }) async {
    final url = Uri.parse('$baseUrl/profile/$userId');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'username': username,
        'bio': bio,
        'avatar': avatar,
      }),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erro ao atualizar perfil');
    }
  }
}
