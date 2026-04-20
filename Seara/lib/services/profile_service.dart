import 'dart:convert';
import 'package:seara/config/api_config.dart';
import 'package:seara/services/api_client.dart';
import 'package:seara/models/profile_model.dart';
import 'package:seara/models/auxiliar/user_with_relationship_model.dart';

class ProfileService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Fetches a user profile from the API
  static Future<Profile> getProfile(int userId) async {
    final url = Uri.parse('$baseUrl/profile/$userId');
    final response = await ApiClient.get(url);

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

    final response = await ApiClient.put(
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

  // Fetches users that can be shown in user pickers
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final url = Uri.parse('$baseUrl/profile/users');
    final response = await ApiClient.get(url);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Erro ao carregar utilizadores');
    }
  }

  static Future<bool> isFollowing({
    required int followerId,
    required int followingId,
  }) async {
    final url = Uri.parse('$baseUrl/profile/isFollowing');
    final response = await ApiClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'followerId': followerId, 'followingId': followingId}),
    );

    final isFollowing = jsonDecode(response.body);

    return isFollowing['isFollowing'];
  }

  static Future<void> follow({
    required int followerId,
    required int followingId,
    required bool isFollowing,
  }) async {
    final endpoint = isFollowing ? 'unfollow' : 'follow';

    final response = await ApiClient.post(
      Uri.parse('$baseUrl/profile/$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'followerId': followerId, 'followingId': followingId}),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erro ao seguir utilizador');
    }
  }

  static Future<List<UserWithRelationship>> getUsersWithRelationship(
    int myId,
  ) async {
    final url = Uri.parse('$baseUrl/profile/users-with-relationship/$myId');
    final response = await ApiClient.get(url);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final users = data.map((u) => UserWithRelationship.fromJson(u)).toList();

      users.sort((a, b) => a.sortWeight.compareTo(b.sortWeight));
      return users;
    } else {
      throw Exception('Erro ao carregar utilizadores');
    }
  }
}
