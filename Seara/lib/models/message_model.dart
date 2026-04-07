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
  final int status; // 0=sent, 1=delivered, 2=read
  final DateTime? deliveredAt;
  final DateTime? expiresAt;
  final bool isSystemMessage;
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
    this.status = 0,
    this.deliveredAt,
    this.expiresAt,
    this.isSystemMessage = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this message has been delivered to at least one recipient.
  bool get isDelivered => status >= 1;

  /// Whether this message has been read by at least one recipient.
  bool get isRead => status >= 2;

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
      status: json['status'] as int? ?? 0,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
      isSystemMessage: json['is_system'] == true || json['user_id'] == 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
