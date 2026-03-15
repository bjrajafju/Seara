enum AttachmentType { image, video, audio, file, none }

class Message {
  final int id;
  final int conversationId;
  final int userId;
  final String body;
  final String? attachment;
  final AttachmentType attachmentType;
  final String? attachmentName;
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
    this.attachmentType = AttachmentType.none,
    this.attachmentName,
    this.senderUsername,
    this.senderAvatar,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final attachmentUrl = json['attachment'] as String?;
    final attachmentMime = json['attachment_type'] as String?;
    final attachmentName = json['attachment_name'] as String?;

    AttachmentType type = AttachmentType.none;
    if (attachmentUrl != null && attachmentMime != null) {
      if (attachmentMime.startsWith('image/')) {
        type = AttachmentType.image;
      } else if (attachmentMime.startsWith('video/')) {
        type = AttachmentType.video;
      } else if (attachmentMime.startsWith('audio/')) {
        type = AttachmentType.audio;
      } else {
        type = AttachmentType.file;
      }
    } else if (attachmentUrl != null) {
      // Fallback: inferir pelo URL quando nao ha mimetype
      final lower = attachmentUrl.toLowerCase();
      if (lower.contains('.mp4') ||
          lower.contains('.mov') ||
          lower.contains('.avi')) {
        type = AttachmentType.video;
      } else if (lower.contains('.mp3') ||
          lower.contains('.m4a') ||
          lower.contains('.wav') ||
          lower.contains('.ogg') ||
          lower.contains('.aac')) {
        type = AttachmentType.audio;
      } else if (lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.png') ||
          lower.contains('.gif') ||
          lower.contains('.webp')) {
        type = AttachmentType.image;
      } else if (attachmentUrl.isNotEmpty) {
        type = AttachmentType.file;
      }
    }

    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      body: json['body'] ?? '',
      attachment: attachmentUrl,
      attachmentType: type,
      attachmentName: attachmentName,
      senderUsername: json['sender_username'],
      senderAvatar: json['sender_avatar'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
