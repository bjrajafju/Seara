import 'profile_model.dart';
import 'message_model.dart';

class Conversation {
  final int id;
  final String? name;
  final bool isGroup;
  final String? image;
  final List<Profile> participants;
  final List<Message> messages;
  final bool isPinned;
  final bool isArchived;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    this.name,
    required this.isGroup,
    this.image,
    required this.participants,
    required this.messages,
    this.isPinned = false,
    this.isArchived = false,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      name: json['name'],
      isGroup: json['is_group'],
      image: json['image'],
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
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
