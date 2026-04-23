import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/link_preview_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/messages/image_lightbox_screen.dart';
import 'package:seara/screens/messages/video_lightbox_screen.dart';
import 'package:seara/screens/messages/widgets/audio_message_widget.dart';
import 'package:seara/screens/messages/widgets/link_preview_card.dart';
import 'package:seara/screens/messages/widgets/message_bubble_wrapper.dart';
import 'package:seara/services/link_preview_service.dart';
import 'package:seara/utils/conversation_theme_helper.dart';
import 'package:url_launcher/url_launcher.dart';

const int _kGroupingMinutes = 5;
final RegExp _urlRegex = RegExp(r'(https?:\/\/[^\s]+)');

class ConversationMessageList extends StatelessWidget {
  const ConversationMessageList({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.isLoadingMore,
    required this.unreadDividerIndex,
    required this.myId,
    required this.highlightMessageId,
    required this.editingMessageId,
    required this.editMessageController,
    required this.messageKeys,
    required this.conversation,
    required this.convThemeId,
    required this.onEditMessage,
    required this.onDeleteMessage,
    required this.onCopyMessage,
    required this.onPinMessage,
    required this.onForwardMessage,
    required this.onReplyMessage,
    required this.onReactToMessage,
    required this.onCancelEdit,
    required this.onSaveEditedMessage,
    required this.onScrollToMessage,
    required this.onDownloadFile,
  });

  final ScrollController scrollController;
  final List<Message> messages;
  final bool isLoadingMore;
  final int? unreadDividerIndex;
  final int? myId;
  final int? highlightMessageId;
  final int? editingMessageId;
  final TextEditingController editMessageController;
  final Map<int, GlobalKey> messageKeys;
  final Conversation conversation;
  final int convThemeId;
  final ValueChanged<Message> onEditMessage;
  final ValueChanged<Message> onDeleteMessage;
  final ValueChanged<Message> onCopyMessage;
  final ValueChanged<Message> onPinMessage;
  final ValueChanged<Message> onForwardMessage;
  final ValueChanged<Message> onReplyMessage;
  final void Function(Message message, String reaction) onReactToMessage;
  final VoidCallback onCancelEdit;
  final ValueChanged<Message> onSaveEditedMessage;
  final ValueChanged<int> onScrollToMessage;
  final Future<void> Function(String url, String fileName) onDownloadFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int extraBefore = 0;
    if (isLoadingMore) extraBefore++;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      itemCount:
          messages.length + extraBefore + (unreadDividerIndex != null ? 1 : 0),
      itemBuilder: (context, rawIndex) {
        if (isLoadingMore && rawIndex == 0) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        int msgIndex = rawIndex - extraBefore;

        if (unreadDividerIndex != null && msgIndex == unreadDividerIndex) {
          return _buildUnreadDivider(theme);
        }
        if (unreadDividerIndex != null && msgIndex > unreadDividerIndex!) {
          msgIndex--;
        }

        if (msgIndex < 0 || msgIndex >= messages.length) {
          return const SizedBox.shrink();
        }

        final message = messages[msgIndex];
        Widget? dateSep;
        if (msgIndex == 0 ||
            !_isSameDay(messages[msgIndex - 1].createdAt, message.createdAt)) {
          dateSep = _buildDateSeparator(theme, message.createdAt);
        }

        if (message.isSystemMessage) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dateSep != null) dateSep,
              _buildSystemMessage(theme, message),
            ],
          );
        }

        final isFirst = _isFirstInGroup(messages, msgIndex);
        final isLast = _isLastInGroup(messages, msgIndex);
        final isHighlighted = message.id == highlightMessageId;

        Widget msgWidget;
        if (editingMessageId == message.id) {
          msgWidget = _buildEditMessageBubble(theme, message);
        } else {
          final isMe = message.userId == myId;
          msgWidget = isMe
              ? _buildMyMessage(context, theme, message, isFirst, isLast)
              : _buildOtherMessage(context, theme, message, isFirst, isLast);
        }

        msgWidget = Align(
          alignment: message.userId == myId
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: msgWidget,
        );

        if (isHighlighted) {
          msgWidget = AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: msgWidget,
          );
        }

        msgWidget = KeyedSubtree(
          key: _keyForMessage(message.id),
          child: msgWidget,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (dateSep != null) dateSep, msgWidget],
        );
      },
    );
  }

  GlobalKey _keyForMessage(int messageId) {
    return messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  bool _isFirstInGroup(List<Message> items, int index) {
    if (index == 0) return true;
    final current = items[index];
    final previous = items[index - 1];
    if (current.userId != previous.userId) return true;
    final diff = current.createdAt.difference(previous.createdAt).inMinutes;
    return diff >= _kGroupingMinutes;
  }

  bool _isLastInGroup(List<Message> items, int index) {
    if (index == items.length - 1) return true;
    final current = items[index];
    final next = items[index + 1];
    if (current.userId != next.userId) return true;
    final diff = next.createdAt.difference(current.createdAt).inMinutes;
    return diff >= _kGroupingMinutes;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Hoje';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'Ontem';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildUnreadDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withAlpha(100),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'mensagens não lidas',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withAlpha(100),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(ThemeData theme, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 48),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(150),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(ThemeData theme, Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(180),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherMessage(
    BuildContext context,
    ThemeData theme,
    Message message,
    bool isFirst,
    bool isLast,
  ) {
    final avatarUrl =
        message.senderAvatar ??
        "https://ui-avatars.com/api/?name=${message.senderUsername ?? 'U'}";

    final currentBgColor = ConversationThemeHelper.getTheme(
      convThemeId,
    ).backgroundColors.first;
    final isLightBg =
        ThemeData.estimateBrightnessForColor(currentBgColor) ==
        Brightness.light;
    final editadaColor = isLightBg
        ? theme.colorScheme.onSurface.withAlpha(170)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 4 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            child: isLast
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
                  )
                : null,
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirst && conversation.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderUsername ?? "",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(right: 48),
                  child: MessageBubbleWrapper(
                    message: message,
                    isMe: false,
                    themeId: convThemeId,
                    onEdit: onEditMessage,
                    onDelete: onDeleteMessage,
                    onCopy: onCopyMessage,
                    onPin: onPinMessage,
                    onForward: onForwardMessage,
                    onReply: onReplyMessage,
                    onReact: onReactToMessage,
                    quickReactions: context
                        .watch<MessagesProvider>()
                        .quickReactions,
                    onReplaceQuickReaction: (slot, emoji) => context
                        .read<MessagesProvider>()
                        .setQuickReactionSlot(slotIndex: slot, emoji: emoji),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.33,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            ConversationThemeHelper.getTheme(
                              convThemeId,
                            ).otherBubbleColor ??
                            theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isFirst ? 16 : 4),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isLast ? 16 : 4),
                          bottomRight: const Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildReplySnippet(theme, message),
                          if (message.isForwarded)
                            _buildForwardTag(theme, false, convThemeId),
                          if (message.body.isNotEmpty) ...[
                            _buildRichMessageText(
                              theme,
                              message.body,
                              textColor: ConversationThemeHelper.getTheme(
                                convThemeId,
                              ).otherTextColor,
                            ),
                            _buildLinkPreview(message.body),
                          ],
                          if (message.attachment != null) ...[
                            if (message.body.isNotEmpty)
                              const SizedBox(height: 6),
                            _buildAttachmentContent(context, theme, message),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _buildReactionsRow(theme, message),
                if (message.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4),
                    child: Text(
                      'editada',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: editadaColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyMessage(
    BuildContext context,
    ThemeData theme,
    Message message,
    bool isFirst,
    bool isLast,
  ) {
    final currentBgColor = ConversationThemeHelper.getTheme(
      convThemeId,
    ).backgroundColors.first;
    final isLightBg =
        ThemeData.estimateBrightnessForColor(currentBgColor) ==
        Brightness.light;
    final editadaColor = isLightBg
        ? theme.colorScheme.onSurface.withAlpha(170)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8 : 2,
        bottom: isLast ? 4 : 0,
        right: 12,
        left: 56,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MessageBubbleWrapper(
            message: message,
            isMe: true,
            themeId: convThemeId,
            onEdit: onEditMessage,
            onDelete: onDeleteMessage,
            onCopy: onCopyMessage,
            onPin: onPinMessage,
            onForward: onForwardMessage,
            onReply: onReplyMessage,
            onReact: onReactToMessage,
            quickReactions: context.watch<MessagesProvider>().quickReactions,
            onReplaceQuickReaction: (slot, emoji) => context
                .read<MessagesProvider>()
                .setQuickReactionSlot(slotIndex: slot, emoji: emoji),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.33,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    ConversationThemeHelper.getTheme(
                      convThemeId,
                    ).myBubbleColor ??
                    theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: Radius.circular(isFirst ? 16 : 4),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: Radius.circular(isLast ? 16 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildReplySnippet(theme, message),
                  if (message.isForwarded)
                    _buildForwardTag(theme, true, convThemeId),
                  if (message.body.isNotEmpty) ...[
                    _buildRichMessageText(
                      theme,
                      message.body,
                      textColor: ConversationThemeHelper.getTheme(
                        convThemeId,
                      ).myTextColor,
                    ),
                    _buildLinkPreview(message.body),
                  ],
                  if (message.attachment != null) ...[
                    if (message.body.isNotEmpty) const SizedBox(height: 6),
                    _buildAttachmentContent(context, theme, message),
                  ],
                ],
              ),
            ),
          ),
          _buildReactionsRow(theme, message),
          if (isLast || message.isEdited)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited)
                    Padding(
                      padding: EdgeInsets.only(right: isLast ? 4 : 0),
                      child: Text(
                        'editada',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: editadaColor,
                        ),
                      ),
                    ),
                  if (isLast) _buildStatusIcon(theme, message),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForwardTag(ThemeData theme, bool isMe, int themeId) {
    final textColor = isMe
        ? (ConversationThemeHelper.getTheme(
                themeId,
              ).myTextColor?.withAlpha(150) ??
              theme.colorScheme.onPrimary.withAlpha(150))
        : (ConversationThemeHelper.getTheme(
                themeId,
              ).otherTextColor?.withAlpha(150) ??
              theme.colorScheme.onSurface.withAlpha(150));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward_rounded, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            "Reencaminhada",
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontStyle: FontStyle.italic,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentContent(
    BuildContext context,
    ThemeData theme,
    Message message,
  ) {
    switch (message.attachmentType) {
      case AttachmentType.image:
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierColor: Theme.of(context).colorScheme.scrim,
              pageBuilder: (_, __, ___) => ImageLightboxScreen(
                imageUrl: message.attachment!,
                fileName: message.attachmentName,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          child: Hero(
            tag: message.attachment!,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                message.attachment!,
                width: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      case AttachmentType.video:
        return _VideoThumbnailWidget(
          url: message.attachment!,
          fileName: message.attachmentName,
        );
      case AttachmentType.audio:
        return AudioMessageWidget(
          messageId: message.id.toString(),
          url: message.attachment!,
        );
      case AttachmentType.file:
        return _buildFileAttachment(theme, message);
      case AttachmentType.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFileAttachment(ThemeData theme, Message message) {
    final name = message.attachmentName ?? 'Ficheiro';
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : '?';
    final icon = _fileIcon(name);

    return GestureDetector(
      onTap: () => onDownloadFile(message.attachment!, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ext,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(ext)) return Icons.description_rounded;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_rounded;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow_rounded;
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildRichMessageText(
    ThemeData theme,
    String text, {
    Color? textColor,
  }) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      height: 1.4,
      color: textColor,
    );
    final linkStyle = style?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
    );
  }

  String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  Widget _buildLinkPreview(String text) {
    final url = _extractUrl(text);
    if (url == null) return const SizedBox.shrink();

    return FutureBuilder<LinkPreview?>(
      future: LinkPreviewService.fetchLinkPreview(url),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return LinkPreviewCard(preview: snapshot.data!);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStatusIcon(ThemeData theme, Message message) {
    IconData icon;
    Color color;
    String tooltip;

    switch (message.status) {
      case 2:
        icon = Icons.done_all_rounded;
        color = theme.colorScheme.primary;
        tooltip = 'Lido';
        break;
      case 1:
        icon = Icons.done_all_rounded;
        color = theme.colorScheme.onSurface.withAlpha(100);
        tooltip = 'Entregue';
        break;
      default:
        icon = Icons.check_rounded;
        color = theme.colorScheme.onSurface.withAlpha(100);
        tooltip = 'Enviado';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildEditMessageBubble(ThemeData theme, Message message) {
    final isMe = message.userId == myId;
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        right: isMe ? 12 : 48,
        left: isMe ? 48 : 12,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: editMessageController,
              maxLines: null,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onCancelEdit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onSaveEditedMessage(message),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Guardar', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplySnippet(ThemeData theme, Message message) {
    if (message.replyToMessageId == null) return const SizedBox.shrink();
    final reply = message.replyTo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => onScrollToMessage(message.replyToMessageId!),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(120),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reply?.senderUsername ?? 'Utilizador',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                reply != null
                    ? _replyPreviewText(reply)
                    : 'Mensagem indisponível',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _replyPreviewText(ReplyPreview reply) {
    if (reply.isUnavailable) return 'Mensagem indisponível';
    if ((reply.body ?? '').trim().isNotEmpty) return reply.body!.trim();
    final type = (reply.attachmentType ?? '').toLowerCase();
    if (type.startsWith('image/')) return '📷 Foto';
    if (type.startsWith('video/')) return '🎥 Vídeo';
    if (type.isNotEmpty) return '📎 Anexo';
    return 'Mensagem indisponível';
  }

  Widget _buildReactionsRow(ThemeData theme, Message message) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions
            .map(
              (reaction) => InkWell(
                onTap: () {
                  if (myId == null) return;
                  onReactToMessage(message, reaction.reaction);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: reaction.reactedByMe
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${reaction.reaction} ${reaction.count}'),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VideoThumbnailWidget extends StatelessWidget {
  const _VideoThumbnailWidget({required this.url, this.fileName});

  final String url;
  final String? fileName;

  void _openLightbox(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Theme.of(context).colorScheme.scrim,
        pageBuilder: (_, __, ___) =>
            VideoLightboxScreen(videoUrl: url, fileName: fileName),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: () => _openLightbox(context),
      child: Container(
        width: 220,
        height: 124,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.scrim.withAlpha(140),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: cs.onInverseSurface,
                size: 34,
              ),
            ),
            if (fileName != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  fileName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withAlpha(200),
                    fontSize: 11,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
