enum AttachmentType { image, video, audio, file, none }

class ReactionAggregate {
  final String reaction;
  final int count;
  final bool reactedByMe;

  const ReactionAggregate({
    required this.reaction,
    required this.count,
    required this.reactedByMe,
  });

  factory ReactionAggregate.fromJson(Map<String, dynamic> json) {
    return ReactionAggregate(
      reaction: (json['reaction'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      reactedByMe: json['reacted_by_me'] == true,
    );
  }
}

class ReplyPreview {
  final int id;
  final int userId;
  final String? senderUsername;
  final String? body;
  final String? attachmentType;
  final String? attachmentName;
  final DateTime? deletedAt;

  const ReplyPreview({
    required this.id,
    required this.userId,
    this.senderUsername,
    this.body,
    this.attachmentType,
    this.attachmentName,
    this.deletedAt,
  });

  bool get isUnavailable => deletedAt != null;

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      senderUsername: json['sender_username']?.toString(),
      body: json['body']?.toString(),
      attachmentType: json['attachment_type']?.toString(),
      attachmentName: json['attachment_name']?.toString(),
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
    );
  }
}

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
  final DateTime? editedAt;
  final bool isForwarded;
  final int? replyToMessageId;
  final ReplyPreview? replyTo;
  final List<ReactionAggregate> reactions;

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
    this.editedAt,
    this.isForwarded = false,
    this.replyToMessageId,
    this.replyTo,
    this.reactions = const [],
  });

  /// Whether this message has been delivered to at least one recipient.
  bool get isDelivered => status >= 1;

  /// Whether this message has been read by at least one recipient.
  bool get isRead => status >= 2;

  /// Whether this message has been edited
  bool get isEdited => editedAt != null || updatedAt.difference(createdAt).inSeconds > 2;

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
      editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at']) : null,
      isForwarded: json['is_forwarded'] == true,
      replyToMessageId: (json['reply_to_message_id'] as num?)?.toInt(),
      replyTo: json['reply_to'] is Map<String, dynamic>
          ? ReplyPreview.fromJson(json['reply_to'] as Map<String, dynamic>)
          : null,
      reactions: ((json['reactions'] as List?) ?? const [])
          .whereType<Map>()
          .map((r) => ReactionAggregate.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }

  Message copyWith({
    String? body,
    String? attachment,
    AttachmentType? attachmentType,
    String? attachmentName,
    String? senderUsername,
    String? senderAvatar,
    int? status,
    DateTime? deliveredAt,
    DateTime? expiresAt,
    bool? isSystemMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? editedAt,
    bool? isForwarded,
    int? replyToMessageId,
    ReplyPreview? replyTo,
    List<ReactionAggregate>? reactions,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      userId: userId,
      body: body ?? this.body,
      attachment: attachment ?? this.attachment,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentName: attachmentName ?? this.attachmentName,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editedAt: editedAt ?? this.editedAt,
      isForwarded: isForwarded ?? this.isForwarded,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
    );
  }
}
