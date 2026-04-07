/// Represents a conversation member with role information.
class ConversationMember {
  final int id;
  final String username;
  final String name;
  final String avatar;
  final int role; // 0=member, 1=admin
  final bool isCreator;

  ConversationMember({
    required this.id,
    required this.username,
    required this.name,
    required this.avatar,
    required this.role,
    required this.isCreator,
  });

  bool get isAdmin => role == 1 || isCreator;

  String get avatarUrl => avatar.isNotEmpty
      ? avatar
      : 'https://ui-avatars.com/api/?name=${username.isNotEmpty ? username : 'U'}';

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    return ConversationMember(
      id: json['id'] as int,
      username: (json['username'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      avatar: (json['avatar'] ?? '') as String,
      role: json['role'] as int? ?? 0,
      isCreator: json['is_creator'] as bool? ?? false,
    );
  }
}

/// Configurable permissions for a conversation.
class ConversationSettings {
  final int whoCanManageMembers; // 0=all, 1=admins
  final int whoCanEditInfo; // 0=all, 1=admins
  final int whoCanSendMessages; // 0=all, 1=admins
  final int whoCanEditBio; // 0=all, 1=admins
  final int ephemeralDuration; // 0=off, 1=24h, 2=7d, 3=30d
  final int theme; // 0=default, 1=ocean, 2=sunset, 3=forest, 4=midnight

  ConversationSettings({
    this.whoCanManageMembers = 0,
    this.whoCanEditInfo = 0,
    this.whoCanSendMessages = 0,
    this.whoCanEditBio = 0,
    this.ephemeralDuration = 0,
    this.theme = 0,
  });

  factory ConversationSettings.fromJson(Map<String, dynamic> json) {
    return ConversationSettings(
      whoCanManageMembers: json['who_can_manage_members'] as int? ?? 0,
      whoCanEditInfo: json['who_can_edit_info'] as int? ?? 0,
      whoCanSendMessages: json['who_can_send_messages'] as int? ?? 0,
      whoCanEditBio: json['who_can_edit_bio'] as int? ?? 0,
      ephemeralDuration: json['ephemeral_duration'] as int? ?? 0,
      theme: json['theme'] as int? ?? 0,
    );
  }

  /// Human-readable label for ephemeral duration.
  String get ephemeralLabel {
    switch (ephemeralDuration) {
      case 1:
        return '24 horas';
      case 2:
        return '7 dias';
      case 3:
        return '30 dias';
      default:
        return 'Desativado';
    }
  }

  /// Human-readable label for theme.
  String get themeLabel {
    switch (theme) {
      case 1:
        return 'Oceano';
      case 2:
        return 'Pôr do Sol';
      case 3:
        return 'Floresta';
      case 4:
        return 'Meia-noite';
      default:
        return 'Padrão';
    }
  }
}

/// Per-user notification preferences for a conversation.
class ConversationNotification {
  final bool isMuted;
  final DateTime? mutedUntil;

  ConversationNotification({this.isMuted = false, this.mutedUntil});

  factory ConversationNotification.fromJson(Map<String, dynamic> json) {
    return ConversationNotification(
      isMuted: json['is_muted'] as bool? ?? false,
      mutedUntil: json['muted_until'] != null
          ? DateTime.tryParse(json['muted_until'])
          : null,
    );
  }

  /// Whether mute is currently effective (not expired).
  bool get isEffectivelyMuted {
    if (!isMuted) return false;
    if (mutedUntil == null) return true; // indefinite
    return DateTime.now().isBefore(mutedUntil!);
  }

  /// Human-readable mute status.
  String get muteLabel {
    if (!isEffectivelyMuted) return 'Ativadas';
    if (mutedUntil == null) return 'Silenciado';
    return 'Silenciado até ${mutedUntil!.day}/${mutedUntil!.month} ${mutedUntil!.hour}:${mutedUntil!.minute.toString().padLeft(2, '0')}';
  }
}

/// Full conversation details including members, settings and notification state.
class ConversationDetails {
  final int id;
  final String? name;
  final bool isGroup;
  final String? image;
  final String? description;
  final List<ConversationMember> members;
  final ConversationSettings? settings;
  final int myRole; // 0=member, 1=admin
  final bool isCreator;
  final bool isPinned;
  final ConversationNotification notification;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationDetails({
    required this.id,
    this.name,
    required this.isGroup,
    this.image,
    this.description,
    required this.members,
    this.settings,
    required this.myRole,
    required this.isCreator,
    required this.isPinned,
    required this.notification,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get amAdmin => myRole == 1 || isCreator;

  factory ConversationDetails.fromJson(Map<String, dynamic> json) {
    return ConversationDetails(
      id: json['id'] as int,
      name: json['name'] as String?,
      isGroup: json['is_group'] as bool,
      image: json['image'] as String?,
      description: json['description'] as String?,
      members:
          (json['members'] as List<dynamic>?)
              ?.map(
                (m) => ConversationMember.fromJson(m as Map<String, dynamic>),
              )
              .toList() ??
          [],
      settings: json['settings'] != null
          ? ConversationSettings.fromJson(
              json['settings'] as Map<String, dynamic>,
            )
          : null,
      myRole: json['my_role'] as int? ?? 0,
      isCreator: json['is_creator'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      notification: json['notification'] != null
          ? ConversationNotification.fromJson(
              json['notification'] as Map<String, dynamic>,
            )
          : ConversationNotification(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
