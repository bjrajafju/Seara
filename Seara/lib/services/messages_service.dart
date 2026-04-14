import 'dart:convert';
import 'package:seara/services/api_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Response from paginated message fetch.
class MessagesPage {
  final List<Message> messages;
  final bool hasMore;
  final DateTime? lastReadAt;
  final int? targetIndex; // Position of target message for jumping
  final int? targetMessageId; // ID of the target message (for highlighting)

  MessagesPage({
    required this.messages,
    required this.hasMore,
    this.lastReadAt,
    this.targetIndex,
    this.targetMessageId,
  });
}

class MessagesService {
  static const String baseUrl = "http://localhost:3000";

  Future<List<Conversation>> fetchConversations(
    int userId, {
    Map<String, String>? filters,
  }) async {
    Uri uri = Uri.parse("$baseUrl/messages/conversations/$userId");
    if (filters != null && filters.isNotEmpty) {
      uri = uri.replace(queryParameters: filters);
    }

    final response = await ApiClient.get(
      uri,
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception("Erro ao carregar conversas");
    }
  }

  Future<Conversation> createConversation({
    required int creatorId,
    required List<int> participantIds,
    String? name,
  }) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/messages/conversations"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "creatorId": creatorId,
        "participantIds": participantIds,
        "name": name,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Conversation.fromJson(data);
    } else {
      throw Exception("Erro ao criar conversa");
    }
  }

  /// Fetch messages with cursor-based pagination or around a target message.
  Future<MessagesPage> fetchMessages(
    int conversationId, {
    int limit = 30,
    int? before,
    int? around,
    int? userId,
  }) async {
    final params = <String, String>{"limit": limit.toString()};
    if (before != null) params['before'] = before.toString();
    if (around != null) params['around'] = around.toString();
    if (userId != null) params['userId'] = userId.toString();

    final uri = Uri.parse(
      "$baseUrl/messages/conversations/$conversationId/messages",
    ).replace(queryParameters: params);

    final response = await ApiClient.get(
      uri,
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final List<dynamic> messagesJson = data['messages'] ?? data;
      final messages = messagesJson.map((m) => Message.fromJson(m)).toList();

      final hasMore = data['has_more'] as bool? ?? false;
      final lastReadAt = data['last_read_at'] != null
          ? DateTime.tryParse(data['last_read_at'])
          : null;

      final targetIndex = data['target_index'] as int?;
      final targetMessageId = data['target_message_id'] as int?;

      return MessagesPage(
        messages: messages,
        hasMore: hasMore,
        lastReadAt: lastReadAt,
        targetIndex: targetIndex,
        targetMessageId: targetMessageId,
      );
    } else {
      throw Exception("Erro ao carregar mensagens");
    }
  }

  Future<Message> sendMessage({
    required int conversationId,
    required int userId,
    required String body,
    String? attachment,
    String? attachmentType,
    String? attachmentName,
    bool isForwarded = false,
    int? replyToMessageId,
  }) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/messages/conversations/$conversationId/messages"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "body": body,
        "attachment": attachment,
        "attachment_type": attachmentType,
        "attachment_name": attachmentName,
        "is_forwarded": isForwarded,
        "reply_to_message_id": replyToMessageId,
      }),
    );

    if (response.statusCode == 201) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      final errBody = jsonDecode(response.body);
      throw Exception(errBody['error'] ?? "Erro ao enviar mensagem");
    }
  }

  Future<bool> toggleReaction({
    required int messageId,
    required int userId,
    required String reaction,
  }) async {
    final response = await ApiClient.post(
      Uri.parse("$baseUrl/messages/$messageId/reactions"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "reaction": reaction,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['added'] == true;
    } else {
      final errBody = jsonDecode(response.body);
      throw Exception(errBody['error'] ?? "Erro ao alternar reação");
    }
  }

  Future<Message> editMessage({
    required int conversationId,
    required int messageId,
    required String newBody,
  }) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/messages/conversations/$conversationId/messages/$messageId"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "body": newBody,
      }),
    );

    if (response.statusCode == 200) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      final errBody = jsonDecode(response.body);
      throw Exception(errBody['error'] ?? "Erro ao editar mensagem");
    }
  }

  Future<void> deleteMessage({
    required int conversationId,
    required int messageId,
  }) async {
    final response = await ApiClient.delete(
      Uri.parse("$baseUrl/messages/conversations/$conversationId/messages/$messageId"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception("Erro ao eliminar mensagem");
    }
  }

  Future<List<Message>> getPinnedMessages(int conversationId) async {
    final response = await ApiClient.get(
      Uri.parse("$baseUrl/messages/conversations/$conversationId/messages/pinned"),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      final errBody = jsonDecode(response.body);
      throw Exception(errBody['error'] ?? "Erro ao carregar mensagens fixadas");
    }
  }

  Future<bool> toggleMessagePin(int conversationId, int messageId) async {
    final response = await ApiClient.put(
      Uri.parse("$baseUrl/messages/conversations/$conversationId/messages/$messageId/pin"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'pinned';
    } else {
      final errBody = jsonDecode(response.body);
      throw Exception(errBody['error'] ?? "Erro ao alternar fixação da mensagem");
    }
  }
}
