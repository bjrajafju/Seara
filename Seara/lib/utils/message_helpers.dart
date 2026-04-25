/// Centralized helper utilities for the messaging system

import 'package:seara/models/conversation_settings_model.dart';
import 'package:seara/utils/conversation_theme_helper.dart';

/// Maps attachment MIME types to Portuguese display labels
String getAttachmentLabel(String? attachmentType) {
  if (attachmentType == null || attachmentType.isEmpty) {
    return 'ficheiro';
  }

  if (attachmentType.startsWith('image/')) {
    return 'imagem';
  }
  if (attachmentType.startsWith('video/')) {
    return 'vídeo';
  }
  if (attachmentType.startsWith('audio/')) {
    return 'áudio';
  }

  return 'ficheiro';
}

/// Gets theme display name from the real theme source
String getThemeDisplayName(int? themeId) {
  return ConversationThemeHelper.getTheme(themeId ?? 0).name;
}

/// Gets reply display text with proper attachment label fallback
String getReplyDisplayText(Map<String, dynamic>? replyMessage) {
  if (replyMessage == null) {
    return 'Mensagem indisponível';
  }

  // Check if message is deleted
  if (replyMessage['is_deleted'] == true ||
      replyMessage['deleted_at'] != null) {
    return 'Mensagem eliminada';
  }

  // Use body if available
  final body = replyMessage['body'] as String?;
  if (body != null && body.isNotEmpty) {
    return body;
  }

  // Use attachment type to generate label
  final attachmentType = replyMessage['attachment_type'] as String?;
  if (attachmentType != null && attachmentType.isNotEmpty) {
    return getAttachmentLabel(attachmentType);
  }

  // Final fallback
  return 'Mensagem indisponível';
}

/// Checks if a user can send messages based on conversation settings
bool canUserSendMessage(ConversationSettings? settings, bool isAdmin) {
  if (settings == null) return false;

  final whoCanSend = settings.whoCanSendMessages;

  switch (whoCanSend) {
    case 0: // Everyone
      return true;
    case 1: // Admins only
      return isAdmin;
    case 2: // Nobody
      return false;
    default:
      return true;
  }
}

/// Gets permission message for UI display
String getPermissionMessage(ConversationSettings? settings, bool isAdmin) {
  if (settings == null) return '';

  final whoCanSend = settings.whoCanSendMessages;

  switch (whoCanSend) {
    case 1: // Admins only
      return isAdmin ? '' : 'Apenas administradores podem enviar mensagens';
    case 2: // Nobody
      return 'Ninguém pode enviar mensagens nesta conversa';
    default:
      return '';
  }
}

/// Filters system users from participants list
List<Map<String, dynamic>> filterSystemUsers(
  List<Map<String, dynamic>> participants,
) {
  return participants.where((participant) {
    final username = participant['username'] as String?;
    if (username == null) return true;

    final lowerUsername = username.toLowerCase();
    return lowerUsername != 'system' && lowerUsername != 'sistema';
  }).toList();
}
