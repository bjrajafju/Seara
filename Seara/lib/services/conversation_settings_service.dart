import 'dart:convert';
import 'package:seara/config/api_config.dart';
import 'package:seara/services/api_client.dart';
import '../models/conversation_settings_model.dart';
import '../models/message_model.dart';

class ConversationSettingsService {
  static String get baseUrl => "${ApiConfig.baseUrl}/messages";

  /// Fetch full conversation details.
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
      return ConversationDetails.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Erro ao obter detalhes da conversa.");
    }
  }

  /// Update conversation name.
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

  /// Update conversation image.
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

  /// Add members to conversation.
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

  /// Remove a member from conversation.
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

  /// Update member role (promote/demote).
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

  /// Update conversation settings (permissions, theme, ephemeral).
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

  /// Update notification preferences for this conversation.
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

  /// Leave conversation (group=remove, 1:1=archive).
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

  /// Toggle pin conversation.
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
      throw Exception("Erro ao fixar/desfixar conversa.");
    }
  }

  /// Mark conversation as read.
  static Future<void> markAsRead(int conversationId, int userId) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/conversations/$conversationId/read"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode != 200) {
      // Silently fail — not critical
    }
  }

  /// Search messages within a conversation.
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
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Message.fromJson(m)).toList();
    } else {
      throw Exception("Erro ao pesquisar mensagens.");
    }
  }

  /// Get shared media of a specific type.
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
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Erro ao obter media partilhada.");
    }
  }
}
