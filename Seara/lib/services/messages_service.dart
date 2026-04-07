import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Response from paginated message fetch.
class MessagesPage {
  final List<Message> messages;
  final bool hasMore;
  final DateTime? lastReadAt;

  MessagesPage({
    required this.messages,
    required this.hasMore,
    this.lastReadAt,
  });
}

class MessagesService {
  static const String baseUrl = "http://localhost:3000";

  Future<List<Conversation>> fetchConversations(int userId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/messages/conversations/$userId"),
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
    final response = await http.post(
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

  /// Fetch messages with cursor-based pagination.
  Future<MessagesPage> fetchMessages(
    int conversationId, {
    int limit = 30,
    int? before,
    int? userId,
  }) async {
    final params = <String, String>{"limit": limit.toString()};
    if (before != null) params['before'] = before.toString();
    if (userId != null) params['userId'] = userId.toString();

    final uri = Uri.parse(
      "$baseUrl/messages/conversations/$conversationId/messages",
    ).replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final List<dynamic> messagesJson = data['messages'] ?? data;
      final messages =
          messagesJson.map((m) => Message.fromJson(m)).toList();

      final hasMore = data['has_more'] as bool? ?? false;
      final lastReadAt = data['last_read_at'] != null
          ? DateTime.tryParse(data['last_read_at'])
          : null;

      return MessagesPage(
        messages: messages,
        hasMore: hasMore,
        lastReadAt: lastReadAt,
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
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/messages/conversations/$conversationId/messages"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "body": body,
        "attachment": attachment,
        "attachment_type": attachmentType,
        "attachment_name": attachmentName,
      }),
    );

    if (response.statusCode == 201) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      final errBody = jsonDecode(response.body);
      throw Exception(errBody['error'] ?? "Erro ao enviar mensagem");
    }
  }

  Future<List<Conversation>> searchConversations(
    int userId,
    String query,
  ) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final uri = Uri.parse(
      "$baseUrl/messages/conversations/search/$userId?q=$encodedQuery",
    );

    final response = await http.get(
      uri,
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception("Erro ao pesquisar conversas");
    }
  }
}
