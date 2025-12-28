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
}
