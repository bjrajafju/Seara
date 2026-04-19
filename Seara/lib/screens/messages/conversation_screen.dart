import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:seara/services/global_audio_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seara/services/api_client.dart' as http;

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/messages/attachment_preview_screen.dart';
import 'package:seara/screens/messages/image_lightbox_screen.dart';
import 'package:seara/screens/messages/video_lightbox_screen.dart';
import 'package:seara/screens/messages/widgets/audio_message_widget.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/audio_service.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/screens/messages/conversation_details_screen.dart';
import 'package:seara/screens/messages/forward_message_screen.dart';
import 'package:seara/utils/conversation_theme_helper.dart';
import 'package:seara/models/link_preview_model.dart';
import 'package:seara/services/link_preview_service.dart';
import 'widgets/link_preview_card.dart';
import 'widgets/message_bubble_wrapper.dart';
import 'package:desktop_drop/desktop_drop.dart';

// Import condicional: usa web em browser, stub em mobile
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

// Intervalo maximo em minutos para agrupar mensagens do mesmo utilizador
const int _kGroupingMinutes = 5;

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversation,
    this.initialScrollToMessageId,
  });

  final Conversation conversation;
  final int? initialScrollToMessageId;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioService _audioService = createAudioService();

  int? _myId;
  late MessagesProvider _messagesProvider;
  bool _isRecording = false;
  bool _hasText = false;
  int? _highlightMessageId;
  int _currentPinnedIndex = 0;
  int _convThemeId = 0;
  bool _isUserNearBottom = true; // Track if user is near bottom
  bool _isJumpingToMessage = false; // Track if we're jumping to a message
  final Map<int, GlobalKey> _messageKeys = {};

  GlobalKey _keyForMessage(int messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  // Action state
  int? _editingMessageId;
  final TextEditingController _editMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _messagesProvider = context.read<MessagesProvider>();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    // Fix: Intercept Enter key natively before it reaches the TextField to prevent paragraph inserts
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (!HardwareKeyboard.instance.isShiftPressed) {
          _sendMessage();
          return KeyEventResult.handled; // Stops event to prevent newline
        }
      }
      return KeyEventResult.ignored;
    };

    _initFilePicker();
    _init();
  }

  void _initFilePicker() {
    if (kIsWeb) {
      FilePicker.platform = FilePicker.platform;
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  /// Detect scroll to top for loading more messages and track scroll position.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pixels = _scrollController.position.pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;

    // Track if user is near bottom (within 100px)
    final wasNearBottom = _isUserNearBottom;
    _isUserNearBottom = (maxExtent - pixels) < 100;

    // If user just moved away from bottom, don't auto-scroll
    if (wasNearBottom && !_isUserNearBottom) {
      // User scrolled up manually, so stop auto-scrolling
      _isUserNearBottom = false;
    }

    // Load more messages if scrolled to top
    if (pixels <= 50 &&
        _messagesProvider.hasMore &&
        !_messagesProvider.isLoadingMore &&
        !_isJumpingToMessage) {
      final prevMax = maxExtent;
      _messagesProvider.loadMore(widget.conversation.id, userId: _myId).then((
        _,
      ) {
        // Maintain scroll position after prepending messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMax = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(
              _scrollController.offset + (newMax - prevMax),
            );
          }
        });
      });
    }
  }

  Future<void> _init() async {
    _myId = await AuthService.getUserId();
    if (!mounted) return;
    // Task 5: Load theme FIRST for smoother perceived performance
    await _loadTheme();

    if (widget.initialScrollToMessageId != null) {
      _scrollToMessage(widget.initialScrollToMessageId!);
    } else {
      await _messagesProvider.loadMessages(
        widget.conversation.id,
        userId: _myId,
      );
      _scrollToBottom();
    }
    // Task 4: Subscribe to real-time messages
    _messagesProvider.subscribeToConversation(widget.conversation.id);
    _messagesProvider.addListener(_onNewMessage);
    // Mark as read after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (_myId != null && mounted) {
        ConversationSettingsService.markAsRead(widget.conversation.id, _myId!);
      }
    });
  }

  // Task 4: Auto-scroll when new messages arrive from realtime (only if at bottom)
  int _lastMessageCount = 0;
  void _onNewMessage() {
    final count = _messagesProvider.messages.length;
    if (count > _lastMessageCount && _lastMessageCount > 0) {
      // Only auto-scroll if user was already at the bottom
      if (_isUserNearBottom && !_isJumpingToMessage) {
        _scrollToBottom(animate: true);
      }
    }
    _lastMessageCount = count;
  }

  Future<void> _loadTheme() async {
    try {
      final details = await ConversationSettingsService.getDetails(
        widget.conversation.id,
        _myId ?? 0,
      );
      if (!mounted) return;
      setState(() => _convThemeId = details.settings?.theme ?? 0);
    } catch (_) {
      // Keep default theme on error
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _messagesProvider.removeListener(_onNewMessage);
    _messageController.dispose();
    _editMessageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _messagesProvider.clear();
    final audio = GlobalAudioManager.instance;
    if (audio.currentMessageId != null) {
      audio.stop();
    }
    super.dispose();
  }

  // Task 8: Reliable scroll-to-bottom with fallback
  void _scrollToBottom({bool animate = false, int attempts = 0}) {
    if (!mounted || _isJumpingToMessage) return; // Prevent conflicts

    if (!_scrollController.hasClients) {
      if (attempts < 10) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _scrollToBottom(animate: animate, attempts: attempts + 1);
          }
        });
      }
      return;
    }

    _isUserNearBottom = true; // Mark that we should be at bottom

    if (animate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(maxExtent);

      // Retry jumping a few times to account for images that change the max extent as they render
      if (attempts < 3) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _scrollToBottom(animate: false, attempts: attempts + 1);
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == null) return;
    _messageController.clear();

    final success = await _messagesProvider.sendMessage(
      conversationId: widget.conversation.id,
      userId: _myId!,
      body: text,
      replyToMessageId: _messagesProvider.replyingTo?.id,
    );

    if (success) _scrollToBottom(animate: true);
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_rounded),
                title: const Text("Imagem"),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(isVideo: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded),
                title: const Text("Video"),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(isVideo: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_rounded),
                title: const Text("Audio"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAudioFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: const Text("Ficheiro"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAnyFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMedia({required bool isVideo}) async {
    final XFile? file = isVideo
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );

    if (file == null || _myId == null) return;

    final bytes = await file.readAsBytes();
    final mimeType = isVideo ? "video/mp4" : "image/jpeg";
    final type = isVideo ? PreviewType.video : PreviewType.image;

    Uint8List finalBytes = bytes;

    if (!isVideo && !kIsWeb) {
      final cropped = await _cropImageBytes(bytes, file.name);
      if (cropped != null) finalBytes = cropped;
    }

    if (!mounted) return;

    await _openPreviewAndSend(
      bytes: finalBytes,
      fileName: file.name.isNotEmpty
          ? file.name
          : (isVideo ? "video.mp4" : "image.jpg"),
      mimeType: mimeType,
      type: type,
    );
  }

  Future<Uint8List?> _cropImageBytes(Uint8List bytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      final cropped = await ImageCropper().cropImage(
        sourcePath: tempFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: "Cortar imagem",
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: "Cortar imagem"),
        ],
      );

      if (cropped == null) return null;
      return await cropped.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );

    if (result == null || result.files.isEmpty || _myId == null) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (!mounted) return;

    await _openPreviewAndSend(
      bytes: file.bytes!,
      fileName: file.name,
      mimeType: "audio/${file.extension ?? 'mp3'}",
      type: PreviewType.audio,
    );
  }

  Future<void> _pickAnyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty || _myId == null) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (!mounted) return;

    final ext = file.extension?.toLowerCase() ?? '';
    PreviewType type = PreviewType.file;
    String mimeType = "application/octet-stream";

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      type = PreviewType.image;
      mimeType = "image/$ext";
    } else if (['mp4', 'mov', 'avi'].contains(ext)) {
      type = PreviewType.video;
      mimeType = "video/$ext";
    } else if (['mp3', 'm4a', 'wav', 'ogg', 'aac', 'webm'].contains(ext)) {
      type = PreviewType.audio;
      mimeType = "audio/$ext";
    }

    await _openPreviewAndSend(
      bytes: file.bytes!,
      fileName: file.name,
      mimeType: mimeType,
      type: type,
    );
  }

  Future<void> _openPreviewAndSend({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required PreviewType type,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewScreen(
          preview: AttachmentPreview(
            bytes: bytes,
            fileName: fileName,
            mimeType: mimeType,
            type: type,
          ),
        ),
      ),
    );

    if (result == null || _myId == null || !mounted) return;

    final success = await _messagesProvider.sendFileMessage(
      conversationId: widget.conversation.id,
      userId: _myId!,
      fileBytes: result['bytes'] as Uint8List,
      fileName: result['fileName'] as String,
      mimeType: result['mimeType'] as String,
      body: result['caption'] as String? ?? "",
      replyToMessageId: _messagesProvider.replyingTo?.id,
    );

    if (success && mounted) _scrollToBottom();
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Erro ao enviar ficheiro.")));
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioService.checkPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permissao de microfone negada.")),
        );
      }
      return;
    }

    try {
      await _audioService.startRecording();
      if (mounted) setState(() => _isRecording = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Nao foi possivel iniciar a gravacao. Verifique o microfone.",
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;

    AudioRecordingResult? recording;
    try {
      recording = await _audioService.stopRecording();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao finalizar gravacao.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }

    if (recording == null || _myId == null) return;
    if (!mounted) return;

    await _openPreviewAndSend(
      bytes: Uint8List.fromList(recording.bytes),
      fileName: recording.fileName,
      mimeType: recording.mimeType,
      type: PreviewType.audio,
    );
  }

  Future<void> _discardRecording() async {
    if (!_isRecording) return;
    await _audioService.cancelRecording();
    if (mounted) setState(() => _isRecording = false);
  }

  // Determina se uma mensagem e a primeira do seu grupo
  bool _isFirstInGroup(List<Message> messages, int index) {
    if (index == 0) return true;
    final current = messages[index];
    final previous = messages[index - 1];
    if (current.userId != previous.userId) return true;
    final diff = current.createdAt.difference(previous.createdAt).inMinutes;
    return diff >= _kGroupingMinutes;
  }

  // Determina se uma mensagem e a ultima do seu grupo
  bool _isLastInGroup(List<Message> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index];
    final next = messages[index + 1];
    if (current.userId != next.userId) return true;
    final diff = next.createdAt.difference(current.createdAt).inMinutes;
    return diff >= _kGroupingMinutes;
  }

  String _getDisplayName() {
    if (widget.conversation.isGroup) {
      return widget.conversation.name ?? "Grupo";
    }
    final other = widget.conversation.participants
        .where((u) => u.id != _myId)
        .toList();
    return other.isNotEmpty ? other.first.username : "Utilizador";
  }

  String _getDisplayAvatar() {
    final other = widget.conversation.participants
        .where((u) => u.id != _myId)
        .toList();
    if (other.isNotEmpty) return other.first.avatarUrl;
    return "https://ui-avatars.com/api/?name=User";
  }

  // Task 6: Drag & drop for web/desktop
  bool _isDragOver = false;

  Widget _wrapWithDropTarget(Widget child) {
    // Fix #3: Use desktop_drop for proper OS-level file drops
    return DropTarget(
      onDragEntered: (_) {
        if (!_isDragOver) setState(() => _isDragOver = true);
      },
      onDragExited: (_) {
        if (_isDragOver) setState(() => _isDragOver = false);
      },
      onDragDone: (detail) async {
        setState(() => _isDragOver = false);
        if (detail.files.isEmpty) return;
        // Process first dropped file (send to preview screen)
        final xFile = detail.files.first;
        final bytes = await xFile.readAsBytes();
        final ext = xFile.name.contains('.')
            ? xFile.name.split('.').last.toLowerCase()
            : '';

        PreviewType type = PreviewType.file;
        String mimeType = "application/octet-stream";

        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
          type = PreviewType.image;
          mimeType = "image/$ext";
        } else if (['mp4', 'mov', 'avi'].contains(ext)) {
          type = PreviewType.video;
          mimeType = "video/$ext";
        } else if (['mp3', 'm4a', 'wav', 'ogg', 'aac', 'webm'].contains(ext)) {
          type = PreviewType.audio;
          mimeType = "audio/$ext";
        }

        if (_myId != null && mounted) {
          await _openPreviewAndSend(
            bytes: bytes,
            fileName: xFile.name,
            mimeType: mimeType,
            type: type,
          );
        }
      },
      child: Stack(
        children: [
          child,
          if (_isDragOver)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withAlpha(40),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Largar ficheiro aqui',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final convTheme = ConversationThemeHelper.getTheme(_convThemeId);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(theme),
        body: _wrapWithDropTarget(
          Container(
            decoration: convTheme.isDefault
                ? null
                : convTheme.backgroundDecoration,
            child: Column(
              children: [
                _buildPinnedMessageBar(theme),
                _buildMessagesList(theme),
                _buildInputArea(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      toolbarHeight: 80,
      elevation: 2,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: theme.colorScheme.onPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          // Tappable avatar + name → navigates to details
          Expanded(
            child: GestureDetector(
              onTap: () => _openDetails(),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(_getDisplayAvatar()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getDisplayName(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_sharp),
            color: theme.colorScheme.onPrimary,
            onPressed: () => _openDetails(),
          ),
        ],
      ),
    );
  }

  void _openDetails() {
    Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationDetailsScreen(
          conversation: widget.conversation,
          myId: _myId ?? 0,
        ),
      ),
    ).then((scrollToMsgId) {
      // FIX #2: Scroll to message from search result
      if (scrollToMsgId != null && mounted) {
        _scrollToMessage(scrollToMsgId);
      }
      if (mounted) {
        _loadTheme();
      }
    });
  }

  // FIX #2: Scroll to and briefly highlight a specific message
  Future<void> _scrollToMessage(int messageId) async {
    _isJumpingToMessage = true;
    setState(() => _highlightMessageId = messageId);

    try {
      final targetIndex = await _messagesProvider.ensureMessageLoadedSafe(
        widget.conversation.id,
        messageId,
        userId: _myId,
      );

      if (!mounted) {
        _isJumpingToMessage = false;
        return;
      }

      if (targetIndex != null) {
        void attemptScroll(int attempts) {
          if (!mounted) {
            _isJumpingToMessage = false;
            return;
          }

          if (!_scrollController.hasClients) {
            if (attempts < 10) {
              Future.delayed(
                const Duration(milliseconds: 50),
                () => attemptScroll(attempts + 1),
              );
            } else {
              _isJumpingToMessage = false;
            }
            return;
          }

          final targetKey = _keyForMessage(messageId);

          // If it's already built, just smoothly ensure visible.
          if (targetKey.currentContext != null) {
            Scrollable.ensureVisible(
              targetKey.currentContext!,
              alignment: 0.35,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            ).whenComplete(() => _isJumpingToMessage = false);
            return;
          }

          // Otherwise, animate roughly near its index to get it built, then ensureVisible.
          final unreadIdx = _messagesProvider.unreadDividerIndex;
          final extraBefore = _messagesProvider.isLoadingMore ? 1 : 0;
          final extraUnread = unreadIdx != null ? 1 : 0;
          final approxItemIndex = targetIndex + extraBefore + extraUnread;

          // Approximate height per row to get close without "reloading" the screen.
          final approxOffset = (approxItemIndex * 88.0 - 120.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );

          _scrollController
              .animateTo(
                approxOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              )
              .whenComplete(() {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (targetKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      targetKey.currentContext!,
                      alignment: 0.35,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    ).whenComplete(() => _isJumpingToMessage = false);
                  } else if (attempts < 10) {
                    Future.delayed(
                      const Duration(milliseconds: 60),
                      () => attemptScroll(attempts + 1),
                    );
                  } else {
                    _isJumpingToMessage = false;
                  }
                });
              });
        }

        attemptScroll(0);

        // Remove highlight after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _highlightMessageId = null);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mensagem indisponível')),
          );
        }
        _isJumpingToMessage = false;
      }
    } catch (e) {
      if (mounted) setState(() => _highlightMessageId = null);
      _isJumpingToMessage = false;
    }
  }

  Widget _buildPinnedMessageBar(ThemeData theme) {
    return Consumer<MessagesProvider>(
      builder: (context, provider, _) {
        final pinned = provider.pinnedMessages;
        if (pinned.isEmpty) return const SizedBox.shrink();

        if (_currentPinnedIndex >= pinned.length) {
          _currentPinnedIndex = 0;
        }

        final currentPin = pinned[_currentPinnedIndex];

        return GestureDetector(
          onTap: () {
            _scrollToMessage(currentPin.id);
            if (pinned.length > 1) {
              setState(() {
                _currentPinnedIndex = (_currentPinnedIndex + 1) % pinned.length;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(200),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pinned.length > 1
                            ? "Mensagem Fixada (${_currentPinnedIndex + 1}/${pinned.length})"
                            : "Mensagem Fixada",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentPin.body.isNotEmpty
                            ? currentPin.body.replaceAll('\n', ' ')
                            : 'Anexo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    return Expanded(
      child: Consumer<MessagesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Text(
                "Erro ao carregar mensagens.",
                style: theme.textTheme.bodyMedium,
              ),
            );
          }
          if (provider.messages.isEmpty) {
            return Center(
              child: Text(
                "Sem mensagens ainda. Diz olá!",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            );
          }

          final messages = provider.messages;
          final unreadIdx = provider.unreadDividerIndex;

          // Total items = messages + optional loading indicator + optional unread divider
          int extraBefore = 0;
          if (provider.isLoadingMore) extraBefore++;

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            itemCount:
                messages.length + extraBefore + (unreadIdx != null ? 1 : 0),
            itemBuilder: (context, rawIndex) {
              // Loading more indicator at top
              if (provider.isLoadingMore && rawIndex == 0) {
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

              // Unread divider
              if (unreadIdx != null && msgIndex == unreadIdx) {
                return _buildUnreadDivider(theme);
              }
              // Offset for unread divider
              if (unreadIdx != null && msgIndex > unreadIdx) {
                msgIndex--;
              }

              if (msgIndex < 0 || msgIndex >= messages.length) {
                return const SizedBox.shrink();
              }

              final message = messages[msgIndex];
              final isMe = message.userId == _myId;

              // Task 2: Date separator between different days
              Widget? dateSep;
              if (msgIndex == 0 ||
                  !_isSameDay(
                    messages[msgIndex - 1].createdAt,
                    message.createdAt,
                  )) {
                dateSep = _buildDateSeparator(theme, message.createdAt);
              }

              // System messages rendered centered
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
              final isHighlighted = message.id == _highlightMessageId;

              Widget msgWidget;
              if (_editingMessageId == message.id) {
                msgWidget = _buildEditMessageBubble(theme, message);
              } else {
                msgWidget = isMe
                    ? _buildMyMessage(theme, message, isFirst, isLast)
                    : _buildOtherMessage(theme, message, isFirst, isLast);
              }

              // Apply alignment relative to whoever sent the message
              msgWidget = Align(
                alignment: message.userId == _myId
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
        },
      ),
    );
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

  // Task 2: Date separator
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

  // System message (joins, leaves, name changes, etc.)
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

  Widget _buildAttachmentContent(ThemeData theme, Message message) {
    switch (message.attachmentType) {
      // Imagem
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

      // Vídeo
      case AttachmentType.video:
        return _VideoThumbnailWidget(
          url: message.attachment!,
          fileName: message.attachmentName,
        );

      // Áudio
      case AttachmentType.audio:
        return AudioMessageWidget(
          messageId: message.id.toString(),
          url: message.attachment!,
        );

      // Ficheiro genérico
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
      onTap: () => _confirmFileDownload(message.attachment!, name),
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

  Future<void> _confirmFileDownload(String url, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deseja fazer download de:'),
            const SizedBox(height: 8),
            Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (kIsWeb) {
      // No browser: dispara o download diretamente via helper JS
      downloadFile(url, fileName);
    } else {
      // Mobile: descarregar via http
      try {
        final response = await http.ApiClient.get(Uri.parse(url));
        if (response.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('"$fileName" descarregado.')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao fazer download.')),
          );
        }
      }
    }
  }

  Widget _buildOtherMessage(
    ThemeData theme,
    Message message,
    bool isFirst,
    bool isLast,
  ) {
    final avatarUrl =
        message.senderAvatar ??
        "https://ui-avatars.com/api/?name=${message.senderUsername ?? 'U'}";

    final currentBgColor = ConversationThemeHelper.getTheme(
      _convThemeId,
    ).backgroundColors.first;
    final isLightBg =
        ThemeData.estimateBrightnessForColor(currentBgColor) ==
        Brightness.light;
    final editadaColor = isLightBg
        ? theme.colorScheme.onSurface.withAlpha(170)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      // Mais espaco antes do primeiro de um grupo, menos entre mensagens do mesmo grupo
      padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 4 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min, // Fix row expanding full width
        children: [
          // Avatar so aparece na ultima mensagem do grupo (visualmente a mais baixa)
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
                // Nome do remetente so na primeira mensagem do grupo
                if (isFirst && widget.conversation.isGroup)
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
                    themeId: _convThemeId,
                    onEdit: _handleEditMessage,
                    onDelete: _handleDeleteMessage,
                    onCopy: _handleCopyMessage,
                    onPin: _handlePinMessage,
                    onForward: _handleForwardMessage,
                    onReply: _handleReplyMessage,
                    onReact: _handleReactToMessage,
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
                              _convThemeId,
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forward_rounded,
                                    size: 12,
                                    color:
                                        ConversationThemeHelper.getTheme(
                                          _convThemeId,
                                        ).otherTextColor?.withAlpha(150) ??
                                        theme.colorScheme.onSurface.withAlpha(
                                          150,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Reencaminhada",
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          ConversationThemeHelper.getTheme(
                                            _convThemeId,
                                          ).otherTextColor?.withAlpha(150) ??
                                          theme.colorScheme.onSurface.withAlpha(
                                            150,
                                          ),
                                      fontStyle: FontStyle.italic,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (message.body.isNotEmpty) ...[
                            _buildRichMessageText(
                              theme,
                              message.body,
                              textColor: ConversationThemeHelper.getTheme(
                                _convThemeId,
                              ).otherTextColor,
                            ),
                            _buildLinkPreview(message.body),
                          ],
                          if (message.attachment != null) ...[
                            if (message.body.isNotEmpty)
                              const SizedBox(height: 6),
                            _buildAttachmentContent(theme, message),
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
    ThemeData theme,
    Message message,
    bool isFirst,
    bool isLast,
  ) {
    final currentBgColor = ConversationThemeHelper.getTheme(
      _convThemeId,
    ).backgroundColors.first;
    final isLightBg =
        ThemeData.estimateBrightnessForColor(currentBgColor) ==
        Brightness.light;
    final editadaColor = isLightBg
        ? theme.colorScheme.onSurface.withAlpha(170)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      // Mais espaço antes do 1.º de um grupo, reduzido entre mensagens do grupo
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
            themeId: _convThemeId,
            onEdit: _handleEditMessage,
            onDelete: _handleDeleteMessage,
            onCopy: _handleCopyMessage,
            onPin: _handlePinMessage,
            onForward: _handleForwardMessage,
            onReply: _handleReplyMessage,
            onReact: _handleReactToMessage,
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
                      _convThemeId,
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forward_rounded,
                            size: 12,
                            color:
                                ConversationThemeHelper.getTheme(
                                  _convThemeId,
                                ).myTextColor?.withAlpha(150) ??
                                theme.colorScheme.onPrimary.withAlpha(150),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Reencaminhada",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  ConversationThemeHelper.getTheme(
                                    _convThemeId,
                                  ).myTextColor?.withAlpha(150) ??
                                  theme.colorScheme.onPrimary.withAlpha(150),
                              fontStyle: FontStyle.italic,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.body.isNotEmpty) ...[
                    _buildRichMessageText(
                      theme,
                      message.body,
                      textColor: ConversationThemeHelper.getTheme(
                        _convThemeId,
                      ).myTextColor,
                    ),
                    _buildLinkPreview(message.body),
                  ],
                  if (message.attachment != null) ...[
                    if (message.body.isNotEmpty) const SizedBox(height: 6),
                    _buildAttachmentContent(theme, message),
                  ],
                ],
              ),
            ),
          ),
          _buildReactionsRow(theme, message),
          // Footer with "editada" and read receipts
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

  static final RegExp _urlRegex = RegExp(r'(https?:\/\/[^\s]+)');

  String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  // Task 9: Clickable links in messages
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

  // FIX #5: Status icon with tooltip
  Widget _buildStatusIcon(ThemeData theme, Message message) {
    IconData icon;
    Color color;
    String tooltip;

    switch (message.status) {
      case 2: // read
        icon = Icons.done_all_rounded;
        color = theme.colorScheme.primary;
        tooltip = 'Lido';
        break;
      case 1: // delivered
        icon = Icons.done_all_rounded;
        color = theme.colorScheme.onSurface.withAlpha(100);
        tooltip = 'Entregue';
        break;
      default: // sent
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

  void _handleEditMessage(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _editMessageController.text = message.body;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editMessageController.clear();
    });
  }

  Future<void> _saveEditedMessage(Message message) async {
    final newText = _editMessageController.text.trim();
    if (newText.isEmpty) return;

    // Optimistic UI updates are handled partially by the provider (if it was synchronous), but we know it awaits network.
    // So we close the edit modal immediately so user doesn't wait:
    _cancelEdit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagem editada'),
        duration: Duration(seconds: 1),
      ),
    );

    // Call provider edit
    final success = await context.read<MessagesProvider>().editMessage(
      conversationId: message.conversationId,
      messageId: message.id,
      newBody: newText,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao editar mensagem. As alterações não foram guardadas.',
          ),
        ),
      );
      // Wait for provider reload to restore original state or let realtime fix it
    }
  }

  Future<void> _handleDeleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mensagem?'),
        content: const Text(
          'Tem a certeza que pretende eliminar esta mensagem?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem eliminada'),
          duration: Duration(seconds: 1),
        ),
      );

      final success = await context.read<MessagesProvider>().deleteMessage(
        conversationId: message.conversationId,
        messageId: message.id,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao eliminar mensagem')),
        );
        // Provider reload can restore it if needed
      }
    }
  }

  void _handleCopyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.body));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensagem copiada')));
  }

  Widget _buildEditMessageBubble(ThemeData theme, Message message) {
    final isMe = message.userId == _myId;
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
              controller: _editMessageController,
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
                  onPressed: _cancelEdit,
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
                  onPressed: () => _saveEditedMessage(message),
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

  void _handlePinMessage(Message message) async {
    final success = await context.read<MessagesProvider>().togglePinMessage(
      widget.conversation.id,
      message,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao modificar o estado de fixacao.')),
      );
    }
  }

  void _handleForwardMessage(Message message) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForwardMessageScreen(message: message, myId: _myId ?? 0),
      ),
    );
  }

  void _handleReplyMessage(Message message) {
    context.read<MessagesProvider>().startReply(message);
    _focusNode.requestFocus();
  }

  void _handleReactToMessage(Message message, String reaction) {
    if (_myId == null) return;
    context.read<MessagesProvider>().toggleReaction(
      messageId: message.id,
      userId: _myId!,
      reaction: reaction,
    );
  }

  Widget _buildInputArea(ThemeData theme) {
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
          child: _isRecording
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

  Widget _buildReplySnippet(ThemeData theme, Message message) {
    if (message.replyToMessageId == null) return const SizedBox.shrink();
    final reply = message.replyTo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _scrollToMessage(message.replyToMessageId!),
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
                  if (_myId == null) return;
                  _messagesProvider.toggleReaction(
                    messageId: message.id,
                    userId: _myId!,
                    reaction: reaction.reaction,
                  );
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

  Widget _buildNormalInput(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          color: theme.colorScheme.onSurface,
          onPressed: _showAttachmentOptions,
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
            if (_hasText) {
              return IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
                onPressed: _sendMessage,
              );
            }
            return IconButton(
              icon: const Icon(Icons.mic_rounded),
              color: theme.colorScheme.primary,
              tooltip: "Gravar audio",
              onPressed: _startRecording,
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
          onPressed: _discardRecording,
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
          onPressed: _stopAndSendRecording,
          tooltip: "Parar e enviar",
        ),
      ],
    );
  }

  Widget _buildMessageField(ThemeData theme) {
    return TextFormField(
      controller: _messageController,
      focusNode: _focusNode,
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

/// Thumbnail clicável para vídeos — abre [VideoLightboxScreen] ao tocar.
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
            // Ícone de play
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
            // Label no canto
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
