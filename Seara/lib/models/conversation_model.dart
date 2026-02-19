import 'profile_model.dart';
import 'message_model.dart';

class Conversation {
  final int id;
  final String? name; // Nome do grupo, null para 1:1
  final bool isGroup;
  final List<Profile> participants; // Users na conversa
  final List<Message> messages; // Mensagens
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    this.name,
    required this.isGroup,
    required this.participants,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      name: json['name'],
      isGroup: json['is_group'],
      participants:
          (json['participants'] as List<dynamic>?)
              ?.map((u) => Profile.fromJson(u))
              .toList() ??
          [],
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((m) => Message.fromJson(m))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
