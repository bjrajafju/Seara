import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_model.dart';

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
}
