import 'dart:convert';
import 'package:seara/config/api_config.dart';
import 'package:seara/services/api_client.dart';
import '../models/conversation_settings_model.dart';
import '../models/message_model.dart';

class ConversationSettingsService {
  static String get baseUrl => "${ApiConfig.baseUrl}/messages";

  static Future<ConversationDetails> getDetails(
    int conversationId,
    int userId,
  ) async {
    final response = await ApiClient.get(
      Uri.parse(
        "$baseUrl/conversations/$conversationId/details?userId=$userId",
      ),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return ConversationDetails.fromJson(responseData);
    } else {
      throw Exception("Erro ao obter detalhes da conversa.");
    }
  }

  static Future<void> updateName(
    int conversationId,
    int userId,
    String name,
  ) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/conversations/$conversationId/name"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId, "name": name}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao atualizar nome.");
    }
  }

  static Future<void> updateImage(
    int conversationId,
    int userId,
    String imageUrl,
  ) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/conversations/$conversationId/image"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId, "image": imageUrl}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao atualizar imagem.");
    }
  }

  static Future<List<ConversationMember>> addMembers(
    int conversationId,
    int userId,
    List<int> memberIds,
  ) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/conversations/$conversationId/members"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId, "memberIds": memberIds}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['added'] as List<dynamic>)
          .map((m) => ConversationMember.fromJson(m))
          .toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao adicionar membros.");
    }
  }

  static Future<void> removeMember(
    int conversationId,
    int targetId,
    int userId,
  ) async {
    final response = await ApiClient.delete(
      Uri.parse(
        "$baseUrl/conversations/$conversationId/members/$targetId?userId=$userId",
      ),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao remover membro.");
    }
  }

  static Future<void> updateMemberRole(
    int conversationId,
    int targetId,
    int userId,
    int role,
  ) async {
    final response = await ApiClient.put(
      Uri.parse(
        "$baseUrl/conversations/$conversationId/members/$targetId/role",
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId, "role": role}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao atualizar cargo.");
    }
  }

  static Future<void> updateSettings(
    int conversationId,
    int userId,
    Map<String, dynamic> settings,
  ) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/conversations/$conversationId/settings"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId, ...settings}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao atualizar definições.");
    }
  }

  static Future<void> updateNotifications(
    int conversationId,
    int userId, {
    required bool isMuted,
    String? mutedUntil,
  }) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/conversations/$conversationId/notifications"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "isMuted": isMuted,
        "mutedUntil": mutedUntil,
      }),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao atualizar notificações.");
    }
  }

  /// Leave conversation
  static Future<void> leaveConversation(int conversationId, int userId) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/conversations/$conversationId/leave"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao sair da conversa.");
    }
  }

  /// Delete conversation
  static Future<void> deleteConversation(int conversationId, int userId) async {
    final response = await ApiClient.delete(
      Uri.parse("$baseUrl/conversations/$conversationId"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? "Erro ao eliminar grupo.");
    }
  }

  /// Toggles pin
  static Future<bool> togglePin(int conversationId, int userId) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/conversations/$conversationId/pin"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['is_pinned'] as bool;
    } else {
      throw Exception("Erro ao afixar/desafixar conversa.");
    }
  }

  /// Mark as read
  static Future<void> markAsRead(int conversationId, int userId) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/conversations/$conversationId/read"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode != 200) {}
  }

  static Future<List<Message>> searchMessages(
    int conversationId,
    int userId, {
    String? query,
    String? type,
    int? senderId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{"userId": userId.toString()};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (type != null) params['type'] = type;
    if (senderId != null) params['senderId'] = senderId.toString();
    if (dateFrom != null) params['from'] = dateFrom;
    if (dateTo != null) params['to'] = dateTo;

    final uri = Uri.parse(
      "$baseUrl/conversations/$conversationId/search",
    ).replace(queryParameters: params);

    final response = await ApiClient.get(uri);

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      final messagesJson = _extractList(data, key: 'messages');
      return messagesJson
          .whereType<Map>()
          .map((m) => Message.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else {
      throw Exception("Erro ao pesquisar mensagens.");
    }
  }

  static Future<List<Map<String, dynamic>>> getSharedMedia(
    int conversationId,
    int userId, {
    String? type,
  }) async {
    final params = <String, String>{"userId": userId.toString()};
    if (type != null) params['type'] = type;

    final uri = Uri.parse(
      "$baseUrl/conversations/$conversationId/media",
    ).replace(queryParameters: params);

    final response = await ApiClient.get(uri);

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);
      final mediaJson = _extractList(data, key: 'items');
      return mediaJson
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } else {
      throw Exception("Erro ao obter media partilhada.");
    }
  }

  static List<dynamic> _extractList(dynamic data, {required String key}) {
    if (data is List) return data;
    if (data is Map) {
      final keyed = data[key];
      if (keyed is List) return keyed;
      if (data['data'] is List) return data['data'] as List<dynamic>;
      if (data['results'] is List) return data['results'] as List<dynamic>;
    }
    return const [];
  }
}
