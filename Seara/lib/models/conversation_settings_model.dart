import 'package:seara/utils/message_helpers.dart';
import '../services/time_service.dart';

class ConversationMember {
  final int id;
  final String username;
  final String name;
  final String avatar;
  final int role;
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
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      role: json['role'] as int? ?? 0,
      isCreator: json['is_creator'] as bool? ?? false,
    );
  }
}

class ConversationSettings {
  final int whoCanManageMembers;
  final int whoCanEditInfo;
  final int whoCanSendMessages;
  final int whoCanEditBio;
  final int ephemeralDuration;
  final int theme;

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

  String get themeLabel {
    return getThemeDisplayName(theme);
  }
}

class ConversationNotification {
  final bool isMuted;
  final DateTime? mutedUntil;

  ConversationNotification({this.isMuted = false, this.mutedUntil});

  factory ConversationNotification.fromJson(Map<String, dynamic> json) {
    return ConversationNotification(
      isMuted: json['is_muted'] as bool? ?? false,
      mutedUntil: json['muted_until'] != null
          ? DateTime.parse(json['muted_until'])
          : null,
    );
  }

  bool get isEffectivelyMuted {
    if (!isMuted) return false;
    if (mutedUntil == null) return true;
    return TimeService.now.isBefore(mutedUntil!);
  }

  String get muteLabel {
    if (!isEffectivelyMuted) return 'Ativadas';
    if (mutedUntil == null) return 'Silenciado';
    return 'Silenciado até ${mutedUntil!.day}/${mutedUntil!.month} ${mutedUntil!.hour}:${mutedUntil!.minute.toString().padLeft(2, '0')}';
  }
}

class ConversationDetails {
  final int id;
  final String? name;
  final bool isGroup;
  final String? image;
  final String? description;
  final List<ConversationMember> members;
  final ConversationSettings? settings;
  final int myRole;
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
    List<ConversationMember> members = [];
    try {
      if (json['members'] != null && json['members'] is List) {
        members = (json['members'] as List<dynamic>)
            .where((m) => m != null)
            .map((m) => ConversationMember.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print("ERROR parsing members: $e");
    }

    ConversationSettings? settings;
    try {
      if (json['settings'] != null && json['settings'] is Map) {
        settings = ConversationSettings.fromJson(
          json['settings'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      print("ERROR parsing settings: $e");
      settings = null;
    }

    ConversationNotification notification = ConversationNotification();
    try {
      if (json['notification'] != null && json['notification'] is Map) {
        notification = ConversationNotification.fromJson(
          json['notification'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      print("ERROR parsing notification: $e");
    }

    // Parse other fields safely
    int id = 0;
    try {
      id = json['id'] as int;
    } catch (e) {
      print("ERROR parsing id: $e");
    }

    String? name;
    try {
      name = json['name'] as String?;
    } catch (e) {
      print("ERROR parsing name: $e");
    }

    bool isGroup = false;
    try {
      isGroup = json['is_group'] as bool;
    } catch (e) {
      print("ERROR parsing is_group: $e");
    }

    String? image;
    try {
      image = json['image'] as String?;
    } catch (e) {
      print("ERROR parsing image: $e");
    }

    String? description;
    try {
      description = json['description'] as String?;
    } catch (e) {
      print("ERROR parsing description: $e");
    }

    int myRole = 0;
    try {
      myRole = json['my_role'] as int? ?? 0;
    } catch (e) {
      print("ERROR parsing my_role: $e");
    }

    bool isCreator = false;
    try {
      isCreator = json['is_creator'] as bool? ?? false;
    } catch (e) {
      print("ERROR parsing is_creator: $e");
    }

    bool isPinned = false;
    try {
      isPinned = json['is_pinned'] as bool? ?? false;
    } catch (e) {
      print("ERROR parsing is_pinned: $e");
    }

    DateTime createdAt = TimeService.now;
    try {
      createdAt = DateTime.parse(json['created_at']);
    } catch (e) {
      print("ERROR parsing created_at: $e");
    }

    DateTime updatedAt = TimeService.now;
    try {
      updatedAt = DateTime.parse(json['updated_at']);
    } catch (e) {
      print("ERROR parsing updated_at: $e");
    }

    return ConversationDetails(
      id: id,
      name: name,
      isGroup: isGroup,
      image: image,
      description: description,
      members: members,
      settings: settings,
      myRole: myRole,
      isCreator: isCreator,
      isPinned: isPinned,
      notification: notification,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
