class Message {
  final int id;
  final int conversationId;
  final int userId;
  final String body;
  final String? attachment;
  final String? senderUsername;
  final String? senderAvatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.body,
    this.attachment,
    this.senderUsername,
    this.senderAvatar,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      body: json['body'] ?? '',
      attachment: json['attachment'],
      senderUsername: json['sender_username'],
      senderAvatar: json['sender_avatar'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
