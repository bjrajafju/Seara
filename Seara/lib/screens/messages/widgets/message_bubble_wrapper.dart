import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:seara/models/message_model.dart';
import 'package:seara/utils/conversation_theme_helper.dart';

class MessageBubbleWrapper extends StatefulWidget {
  final Message message;
  final bool isMe;
  final Widget child;
  final int themeId;
  final Function(Message) onEdit;
  final Function(Message) onDelete;
  final Function(Message) onCopy;
  final Function(Message) onPin;
  final Function(Message) onForward;

  const MessageBubbleWrapper({
    super.key,
    required this.message,
    required this.isMe,
    required this.child,
    required this.themeId,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onPin,
    required this.onForward,
  });

  @override
  State<MessageBubbleWrapper> createState() => _MessageBubbleWrapperState();
}

class _MessageBubbleWrapperState extends State<MessageBubbleWrapper> {
  bool _isHovered = false;
  bool _isMenuOpen = false;

  bool get _shouldEnableHover {
    if (kIsWeb) return true;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return true;
    return false;
  }

  void _onEnter() {
    setState(() => _isHovered = true);
  }

  void _onExit() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isMenuOpen) {
        setState(() => _isHovered = false);
      }
    });
  }

  void _showContextMenu(Offset globalPosition) {
    if (!mounted) return;
    if (widget.message.isSystemMessage) return;

    final age = DateTime.now().difference(widget.message.createdAt);
    final canModify = widget.isMe && age < const Duration(hours: 24);

    final overlay = Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    setState(() => _isMenuOpen = true);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(0, 0),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (canModify)
          PopupMenuItem<String>(
            value: 'edit',
            onTap: () => widget.onEdit(widget.message),
            child: const Text('Editar mensagem'),
          ),
        PopupMenuItem<String>(
          value: 'copy',
          onTap: () => widget.onCopy(widget.message),
          child: const Text('Copiar'),
        ),
        PopupMenuItem<String>(
          value: 'pin',
          onTap: () => widget.onPin(widget.message),
          child: const Text('Fixar (trigger)'),
        ),
        PopupMenuItem<String>(
          value: 'forward',
          onTap: () => widget.onForward(widget.message),
          child: const Text('Reencaminhar (trigger)'),
        ),
        if (canModify)
          PopupMenuItem<String>(
            value: 'delete',
            onTap: () => widget.onDelete(widget.message),
            child: const Text('Eliminar mensagem'),
          ),
      ],
    ).then((_) {
      if (mounted) {
        setState(() {
          _isMenuOpen = false;
          _isHovered = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isSystemMessage) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final convTheme = ConversationThemeHelper.getTheme(widget.themeId);

    final Color arrowColor = widget.isMe
        ? (convTheme.myTextColor ?? theme.colorScheme.onPrimary)
        : (convTheme.otherTextColor ?? theme.colorScheme.onSurfaceVariant);

    return MouseRegion(
      onEnter: _shouldEnableHover ? (_) => _onEnter() : null,
      onExit: _shouldEnableHover ? (_) => _onExit() : null,
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition),
        onLongPressStart: (details) => _showContextMenu(details.globalPosition),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              foregroundDecoration: _isHovered
                  ? BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: widget.child,
            ),
            if (_shouldEnableHover)
              Positioned(
                top: 4,
                right: 4,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isHovered || _isMenuOpen ? 1.0 : 0.0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTapDown: (details) => _showContextMenu(details.globalPosition),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
                          ],
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: theme.colorScheme.onSurface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
