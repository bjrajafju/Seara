import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';

class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.isRecording,
    required this.hasText,
    required this.onShowAttachmentOptions,
    required this.onSendMessage,
    required this.onStartRecording,
    required this.onDiscardRecording,
    required this.onStopAndSendRecording,
  });

  final TextEditingController messageController;
  final FocusNode focusNode;
  final bool isRecording;
  final bool hasText;
  final VoidCallback onShowAttachmentOptions;
  final VoidCallback onSendMessage;
  final VoidCallback onStartRecording;
  final VoidCallback onDiscardRecording;
  final VoidCallback onStopAndSendRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            blurRadius: 3,
            color: theme.colorScheme.shadow.withAlpha(50),
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: isRecording
              ? _buildRecordingIndicator(theme)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReplyComposerPreview(theme),
                    _buildNormalInput(theme),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildReplyComposerPreview(ThemeData theme) {
    return Consumer<MessagesProvider>(
      builder: (context, provider, _) {
        final reply = provider.replyingTo;
        if (reply == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Respondendo a ${reply.senderUsername ?? 'Utilizador'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _replyPreviewText(reply),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: provider.cancelReply,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        );
      },
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

  Widget _buildNormalInput(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          color: theme.colorScheme.onSurface,
          onPressed: onShowAttachmentOptions,
        ),
        Expanded(child: _buildMessageField(theme)),
        const SizedBox(width: 8),
        Consumer<MessagesProvider>(
          builder: (context, provider, _) {
            if (provider.isSending) {
              return const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (hasText) {
              return IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
                onPressed: onSendMessage,
              );
            }
            return IconButton(
              icon: const Icon(Icons.mic_rounded),
              color: theme.colorScheme.primary,
              tooltip: "Gravar audio",
              onPressed: onStartRecording,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete_rounded),
          color: theme.colorScheme.error,
          onPressed: onDiscardRecording,
          tooltip: "Descartar",
        ),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "A gravar...",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.stop_rounded),
          color: theme.colorScheme.primary,
          onPressed: onStopAndSendRecording,
          tooltip: "Parar e enviar",
        ),
      ],
    );
  }

  Widget _buildMessageField(ThemeData theme) {
    return TextFormField(
      controller: messageController,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      maxLines: 6,
      minLines: 1,
      decoration: InputDecoration(
        hintText: 'Escreva uma mensagem...',
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\t'))],
    );
  }
}
