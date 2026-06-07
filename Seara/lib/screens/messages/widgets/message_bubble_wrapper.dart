import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show Listenable, kIsWeb;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../../services/time_service.dart';

import 'package:seara/models/message_model.dart';

class _EmojiPickerCustomView extends StatefulWidget {
  const _EmojiPickerCustomView({
    required this.categoryEmoji,
    required this.onEmojiTap,
  });

  final List<CategoryEmoji> categoryEmoji;
  final ValueChanged<String> onEmojiTap;

  @override
  State<_EmojiPickerCustomView> createState() => _EmojiPickerCustomViewState();
}

class _EmojiPickerCustomViewState extends State<_EmojiPickerCustomView> {
  final TextEditingController _search = TextEditingController();
  int _categoryIndex = 0;

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textUnit = (theme.textTheme.bodyMedium?.fontSize ?? 14.0);
    final outerPad = (textUnit * 0.65).clamp(8.0, 16.0);
    final innerPad = (textUnit * 0.45).clamp(6.0, 14.0);
    final query = _search.text.trim().toLowerCase();

    final categories = widget.categoryEmoji;
    final safeCategoryIndex = _categoryIndex.clamp(
      0,
      (categories.isEmpty ? 0 : categories.length - 1),
    );
    final selectedCategory = categories.isNotEmpty
        ? categories[safeCategoryIndex]
        : null;

    final List<Emoji> emojis;
    if (query.isNotEmpty) {
      final all = categories.expand((c) => c.emoji).toList();
      emojis = all
          .where(
            (e) =>
                e.name.toLowerCase().contains(query) || e.emoji.contains(query),
          )
          .toList();
    } else {
      emojis = selectedCategory?.emoji ?? const [];
    }

    final maxWidth = MediaQuery.of(context).size.width;
    final columns = maxWidth < 360 ? 7 : 8;

    return Padding(
      padding: EdgeInsets.all(outerPad),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: innerPad),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar emoji…',
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (query.isEmpty && categories.isNotEmpty)
            SizedBox(
              height: (textUnit * 2.2).clamp(30.0, 44.0),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: (textUnit * 0.4).clamp(4.0, 10.0)),
                itemBuilder: (context, i) {
                  final selected = i == safeCategoryIndex;
                  final Widget iconWidget = Text(
                    categories[i].emoji.isNotEmpty
                        ? categories[i].emoji.first.emoji
                        : '🙂',
                    style: const TextStyle(fontSize: 16),
                  );
                  return InkWell(
                    onTap: () => setState(() => _categoryIndex = i),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: EdgeInsets.symmetric(
                        horizontal: (textUnit * 0.7).clamp(8.0, 14.0),
                        vertical: (textUnit * 0.25).clamp(2.0, 6.0),
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: iconWidget,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.only(top: innerPad),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final e = emojis[index].emoji;
                return Draggable<String>(
                  data: e,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  child: InkResponse(
                    radius: 22,
                    onTap: () => widget.onEmojiTap(e),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionOverlayManager {
  static OverlayEntry? _barrier;
  static OverlayEntry? _bubble;
  static OverlayEntry? _emojiPicker;

  /// Close all
  static void closeAll() {
    _emojiPicker?.remove();
    _emojiPicker = null;
    _bubble?.remove();
    _bubble = null;
    _barrier?.remove();
    _barrier = null;
  }
}

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
  final Function(Message) onReply;
  final Function(Message, String) onReact;
  final List<String> quickReactions;
  final Function(int slotIndex, String emoji) onReplaceQuickReaction;

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
    required this.onReply,
    required this.onReact,
    required this.quickReactions,
    required this.onReplaceQuickReaction,
  });

  @override
  State<MessageBubbleWrapper> createState() => _MessageBubbleWrapperState();
}

class _MessageBubbleWrapperState extends State<MessageBubbleWrapper> {
  final ValueNotifier<bool> _hovered = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _menuOpen = ValueNotifier<bool>(false);
  final LayerLink _layerLink = LayerLink();

  late final Listenable _hoverListenable = Listenable.merge([
    _hovered,
    _menuOpen,
  ]);

  bool get _shouldEnableHover {
    if (kIsWeb) return true;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return true;
    return false;
  }

  /// Handles enter
  void _onEnter() {
    _hovered.value = true;
  }

  /// Handles exit
  void _onExit() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_menuOpen.value) {
        _hovered.value = false;
      }
    });
  }

  /// Shows context menu
  void _showContextMenu(Offset globalPosition) {
    if (!mounted) return;
    if (widget.message.isSystemMessage) return;

    final age = TimeService.now.difference(widget.message.createdAt);
    final canModify = widget.isMe && age < const Duration(hours: 24);

    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    _menuOpen.value = true;

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
          value: 'reply',
          onTap: () => widget.onReply(widget.message),
          child: const Text('Responder'),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          onTap: () => widget.onCopy(widget.message),
          child: const Text('Copiar'),
        ),
        PopupMenuItem<String>(
          value: 'pin',
          onTap: () => widget.onPin(widget.message),
          child: const Text('Fixar'),
        ),
        PopupMenuItem<String>(
          value: 'forward',
          onTap: () => widget.onForward(widget.message),
          child: const Text('Reencaminhar'),
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
        _menuOpen.value = false;
        _hovered.value = false;
      }
    });
  }

  /// Returns widget rect
  Rect? _getWidgetRect() {
    final overlayBox =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    final box = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & box.size;
  }

  /// Opens reaction bubble
  void _openReactionBubble() {
    if (!mounted || widget.message.isSystemMessage) return;
    _ReactionOverlayManager.closeAll();

    final widgetRect = _getWidgetRect();
    if (widgetRect == null) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    final overlaySize = overlayBox.size;

    _ReactionOverlayManager._barrier = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _ReactionOverlayManager.closeAll,
          child: const SizedBox.expand(),
        ),
      ),
    );

    _ReactionOverlayManager._bubble = OverlayEntry(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final media = MediaQuery.of(ctx);

        final minTop = media.padding.top + 56.0;
        const gap = 6.0;

        const barHeight = 52.0;

        final spaceAbove = widgetRect.top - minTop;
        final spaceBelow =
            overlaySize.height - media.padding.bottom - widgetRect.bottom;
        final showAbove =
            spaceAbove >= (barHeight + gap) || spaceAbove >= spaceBelow;

        double top;
        if (showAbove) {
          top = widgetRect.top - barHeight - gap;
          if (top < minTop) top = minTop;
        } else {
          top = widgetRect.bottom + gap;
          final maxBottom =
              overlaySize.height - media.padding.bottom - barHeight - gap;
          if (top > maxBottom) top = maxBottom;
        }

        const hPadding = 12.0;
        const estimatedBarW = 280.0;
        double left = widgetRect.center.dx - estimatedBarW / 2;
        left = left.clamp(
          hPadding,
          overlaySize.width - estimatedBarW - hPadding,
        );

        return Positioned(
          top: top,
          left: left,
          child: CompositedTransformTarget(
            link: _layerLink,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                builder: (_, t, child) => Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.88 + 0.12 * t,
                    alignment: showAbove
                        ? Alignment.bottomCenter
                        : Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < widget.quickReactions.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: DragTarget<String>(
                              onWillAcceptWithDetails: (_) => true,
                              onAcceptWithDetails: (details) {
                                widget.onReplaceQuickReaction(i, details.data);
                              },
                              builder: (context, candidateData, _) {
                                final isHovering = candidateData.isNotEmpty;
                                return InkResponse(
                                  radius: 22,
                                  onTap: () {
                                    widget.onReact(
                                      widget.message,
                                      widget.quickReactions[i],
                                    );
                                    _ReactionOverlayManager.closeAll();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isHovering
                                          ? theme
                                                .colorScheme
                                                .surfaceContainerHighest
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      widget.quickReactions[i],
                                      style: const TextStyle(
                                        fontSize: 22,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(width: 4),
                        InkResponse(
                          radius: 22,
                          onTap: () => _openEmojiPicker(
                            showAbove: showAbove,
                            barTopLeft: Offset(left, top),
                            barHeight: barHeight,
                            overlaySize: overlaySize,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_ReactionOverlayManager._barrier!);
    overlay.insert(_ReactionOverlayManager._bubble!);
  }

  void _openEmojiPicker({
    required bool showAbove,
    required Offset barTopLeft,
    required double barHeight,
    required Size overlaySize,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _ReactionOverlayManager._emojiPicker?.remove();

    _ReactionOverlayManager._emojiPicker = OverlayEntry(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final media = MediaQuery.of(ctx);

        const pickerW = 300.0;
        const pickerH = 320.0;
        const gap = 6.0;
        final minTop = media.padding.top + 56.0;
        final maxBottom = overlaySize.height - media.padding.bottom;

        double top;
        if (showAbove) {
          top = barTopLeft.dy - pickerH - gap;
          if (top < minTop) {
            top = barTopLeft.dy + barHeight + gap;
          }
        } else {
          top = barTopLeft.dy + barHeight + gap;
          if (top + pickerH > maxBottom) {
            top = barTopLeft.dy - pickerH - gap;
          }
        }
        top = top.clamp(minTop, maxBottom - pickerH);

        const hPadding = 12.0;
        double left =
            barTopLeft.dx +
            ( /* estimated bar width */ 280.0 / 2) -
            pickerW / 2;
        left = left.clamp(hPadding, overlaySize.width - pickerW - hPadding);

        return Positioned(
          top: top,
          left: left,
          width: pickerW,
          height: pickerH,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: EmojiPicker(
                    onEmojiSelected: (_, emoji) {
                      widget.onReact(widget.message, emoji.emoji);
                      _ReactionOverlayManager.closeAll();
                    },
                    config: Config(
                      height: pickerH,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: const EmojiViewConfig(
                        columns: 8,
                        emojiSizeMax: 26,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: theme.colorScheme.surface,
                      ),
                    ),
                    customWidget: (config, state, showSearchBar) {
                      return _EmojiPickerCustomView(
                        categoryEmoji: state.categoryEmoji.skip(1).toList(),
                        onEmojiTap: (e) {
                          widget.onReact(widget.message, e);
                          _ReactionOverlayManager.closeAll();
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_ReactionOverlayManager._emojiPicker!);
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _hovered.dispose();
    _menuOpen.dispose();
    super.dispose();
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    if (widget.message.isSystemMessage) {
      return widget.child;
    }

    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: _shouldEnableHover ? (_) => _onEnter() : null,
        onExit: _shouldEnableHover ? (_) => _onExit() : null,
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              _showContextMenu(details.globalPosition),
          onLongPress: _shouldEnableHover ? null : _openReactionBubble,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(child: widget.child),
              AnimatedBuilder(
                animation: _hoverListenable,
                builder: (context, _) {
                  final showHover = _hovered.value || _menuOpen.value;
                  if (!showHover) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.04,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_shouldEnableHover)
                AnimatedBuilder(
                  animation: _hoverListenable,
                  builder: (context, _) {
                    final show = _hovered.value || _menuOpen.value;
                    return Positioned(
                      top: 4,
                      right: 28,
                      child: IgnorePointer(
                        ignoring: !show,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: show ? 1.0 : 0.0,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _openReactionBubble,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.85,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.emoji_emotions_outlined,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (_shouldEnableHover)
                AnimatedBuilder(
                  animation: _hoverListenable,
                  builder: (context, _) {
                    final show = _hovered.value || _menuOpen.value;
                    return Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
                        ignoring: !show,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: show ? 1.0 : 0.0,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTapDown: (details) =>
                                  _showContextMenu(details.globalPosition),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.85,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.shadow.withAlpha(
                                        30,
                                      ),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
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
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
