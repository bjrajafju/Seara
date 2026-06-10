import 'dart:io';
import 'package:seara/services/global_audio_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/messages/attachment_preview_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/audio_service.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/screens/messages/conversation_details_screen.dart';
import 'package:seara/screens/messages/forward_message_screen.dart';
import 'package:seara/utils/conversation_theme_helper.dart';
import 'package:seara/utils/message_helpers.dart';
import 'widgets/conversation_message_list.dart';
import 'widgets/message_input_bar.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'download_helper_io.dart'
    if (dart.library.html) 'download_helper_web.dart';

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
  bool _isUserNearBottom = true;
  bool _isJumpingToMessage = false;
  final Map<int, GlobalKey> _messageKeys = {};

  // Permission checking
  dynamic _conversationDetails;

  /// Key for message
  GlobalKey _keyForMessage(int messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  int? _editingMessageId;
  final TextEditingController _editMessageController = TextEditingController();

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _messagesProvider = context.read<MessagesProvider>();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (!HardwareKeyboard.instance.isShiftPressed) {
          _sendMessage();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _initFilePicker();
    _init();
  }

  /// Init file picker
  void _initFilePicker() {
    if (kIsWeb) {
      FilePicker.platform = FilePicker.platform;
    }
  }

  /// Handles text changed
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  /// Handles scroll
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pixels = _scrollController.position.pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;

    final wasNearBottom = _isUserNearBottom;
    _isUserNearBottom = (maxExtent - pixels) < 100;

    if (wasNearBottom && !_isUserNearBottom) {
      _isUserNearBottom = false;
    }

    if (pixels <= 50 &&
        _messagesProvider.hasMore &&
        !_messagesProvider.isLoadingMore &&
        !_isJumpingToMessage) {
      final prevMax = maxExtent;
      _messagesProvider.loadMore(widget.conversation.id, userId: _myId).then((
        _,
      ) {
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

  /// Initializes local dependencies and startup state
  Future<void> _init() async {
    _myId = await AuthService.getUserId();
    if (!mounted) return;

    // Load conversation details after userId is available
    _loadConversationDetails();

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
    _messagesProvider.subscribeToConversation(widget.conversation.id);
    _messagesProvider.addListener(_onNewMessage);
    Future.delayed(const Duration(seconds: 1), () {
      if (_myId != null && mounted) {
        ConversationSettingsService.markAsRead(widget.conversation.id, _myId!);
      }
    });
  }

  int _lastMessageCount = 0;

  /// Handles new message
  void _onNewMessage() {
    final count = _messagesProvider.messages.length;
    if (count > _lastMessageCount && _lastMessageCount > 0) {
      if (_isUserNearBottom && !_isJumpingToMessage) {
        _scrollToBottom(animate: true);
      }
    }
    _lastMessageCount = count;
  }

  /// Loads conversation details for permission checking
  Future<void> _loadConversationDetails() async {
    try {
      if (_myId == null) {
        print("ERROR: userId is null, skipping API call");
        return;
      }

      final details = await ConversationSettingsService.getDetails(
        widget.conversation.id,
        _myId!,
      );
      if (!mounted) return;

      setState(() {
        _conversationDetails = details;
        _convThemeId = details.settings?.theme ?? 0;
      });
    } catch (_) {
      // Handle error silently - conversation details will remain null
      print("DEBUG: Exception in _loadConversationDetails");
    }
  }

  /// Loads theme
  Future<void> _loadTheme() async {
    try {
      final details = await ConversationSettingsService.getDetails(
        widget.conversation.id,
        _myId ?? 0,
      );
      if (!mounted) return;
      setState(() => _convThemeId = details.settings?.theme ?? 0);
    } catch (_) {}
  }

  @override
  /// Releases controllers and subscriptions used by this widget
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

  /// Scroll to bottom
  void _scrollToBottom({bool animate = false, int attempts = 0}) {
    if (!mounted || _isJumpingToMessage) return;

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

    _isUserNearBottom = true;

    if (animate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(maxExtent);

      if (attempts < 3) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _scrollToBottom(animate: false, attempts: attempts + 1);
        });
      }
    }
  }

  /// Sends the current message and attachments
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

  /// Opens the attachment picker actions
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

  /// Picks media
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

  /// Crop image bytes
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

  /// Picks audio file
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

  /// Picks any file
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

  /// Starts recording
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

  /// Stops and send recording
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

  /// Discard recording
  Future<void> _discardRecording() async {
    if (!_isRecording) return;
    await _audioService.cancelRecording();
    if (mounted) setState(() => _isRecording = false);
  }

  /// Returns display name
  String _getDisplayName() {
    if (widget.conversation.isGroup) {
      return widget.conversation.name ?? "Grupo";
    }
    final other = widget.conversation.participants
        .where((u) => u.id != _myId)
        .toList();
    return other.isNotEmpty ? other.first.username : "Utilizador";
  }

  /// Returns display avatar
  String _getDisplayAvatar() {
    if (widget.conversation.isGroup) {
      return widget.conversation.image?.isNotEmpty == true
          ? widget.conversation.image!
          : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.conversation.name ?? 'Group')}";
    }

    final other = widget.conversation.participants
        .where((u) => u.id != _myId)
        .toList();

    if (other.isNotEmpty && other.first.avatarUrl.isNotEmpty) {
      return other.first.avatarUrl;
    }

    return "https://ui-avatars.com/api/?name=User";
  }

  ImageProvider? _getAvatarImage() {
    if (widget.conversation.isGroup) {
      if (widget.conversation.image != null &&
          widget.conversation.image!.isNotEmpty) {
        return NetworkImage(widget.conversation.image!);
      }
      if (widget.conversation.name != null &&
          widget.conversation.name!.trim().isNotEmpty) {
        return NetworkImage(
          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.conversation.name!)}",
        );
      }
      return null;
    }

    final other = widget.conversation.participants
        .where((u) => u.id != _myId)
        .toList();
    if (other.isNotEmpty && other.first.avatarUrl.isNotEmpty) {
      return NetworkImage(other.first.avatarUrl);
    }
    final otherUsername = other.isNotEmpty ? other.first.username : 'User';
    return NetworkImage(
      "https://ui-avatars.com/api/?name=${Uri.encodeComponent(otherUsername)}",
    );
  }

  Widget? _getAvatarChild(ThemeData theme) {
    if (widget.conversation.isGroup &&
        (widget.conversation.image == null ||
            widget.conversation.image!.isEmpty) &&
        (widget.conversation.name == null ||
            widget.conversation.name!.trim().isEmpty)) {
      return Icon(
        Icons.group_rounded,
        color: theme.colorScheme.primary,
        size: 20,
      );
    }
    return null;
  }

  Color? _getAvatarBgColor(ThemeData theme) {
    if (widget.conversation.isGroup &&
        (widget.conversation.image == null ||
            widget.conversation.image!.isEmpty) &&
        (widget.conversation.name == null ||
            widget.conversation.name!.trim().isEmpty)) {
      return theme.colorScheme.primaryContainer;
    }
    return null;
  }

  bool _isDragOver = false;

  /// Wrap with drop target
  Widget _wrapWithDropTarget(Widget child) {
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
  /// Builds the widget tree for this view
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

  /// Builds app bar
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
          Expanded(
            child: GestureDetector(
              onTap: () => _openDetails(),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: _getAvatarImage(),
                    backgroundColor: _getAvatarBgColor(theme),
                    child: _getAvatarChild(theme),
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

  /// Opens details
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
      if (scrollToMsgId != null && mounted) {
        _scrollToMessage(scrollToMsgId);
      }
      if (mounted) {
        _loadTheme();
      }
    });
  }

  /// Scroll to message
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
        /// Attempt scroll
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

          if (targetKey.currentContext != null) {
            Scrollable.ensureVisible(
              targetKey.currentContext!,
              alignment: 0.35,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            ).whenComplete(() => _isJumpingToMessage = false);
            return;
          }

          final unreadIdx = _messagesProvider.unreadDividerIndex;
          final extraBefore = _messagesProvider.isLoadingMore ? 1 : 0;
          final extraUnread = unreadIdx != null ? 1 : 0;
          final approxItemIndex = targetIndex + extraBefore + extraUnread;

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

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _highlightMessageId = null);
        });
      } else {
        // Message not found - log error
        print(
          "ERROR: Pinned message $messageId not found in conversation ${widget.conversation.id}",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mensagem indisponível')),
          );
        }
        _isJumpingToMessage = false;
      }
    } catch (e) {
      // Error loading message - log error
      print("ERROR: Failed to load pinned message $messageId: $e");
      if (mounted) setState(() => _highlightMessageId = null);
      _isJumpingToMessage = false;
    }
  }

  /// Builds pinned message bar
  Widget _buildPinnedMessageBar(ThemeData theme) {
    return Consumer<MessagesProvider>(
      builder: (context, provider, _) {
        final pinned = provider.pinnedMessages;

        // Filter by conversation_id to prevent cross-conversation leakage
        final currentConversationPinned = pinned
            .where((msg) => msg.conversationId == widget.conversation.id)
            .toList();

        if (currentConversationPinned.isEmpty) return const SizedBox.shrink();

        if (_currentPinnedIndex >= currentConversationPinned.length) {
          _currentPinnedIndex = 0;
        }

        final currentPin = currentConversationPinned[_currentPinnedIndex];

        return GestureDetector(
          onTap: () {
            _scrollToMessage(currentPin.id);
            if (currentConversationPinned.length > 1) {
              setState(() {
                _currentPinnedIndex =
                    (_currentPinnedIndex + 1) %
                    currentConversationPinned.length;
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
                        currentConversationPinned.length > 1
                            ? "Mensagem Fixada (${_currentPinnedIndex + 1}/${currentConversationPinned.length})"
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
                            : getAttachmentLabel(
                                currentPin.attachmentType.toString(),
                              ),
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

  /// Builds messages list
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

          return ConversationMessageList(
            scrollController: _scrollController,
            messages: provider.messages,
            isLoadingMore: provider.isLoadingMore,
            unreadDividerIndex: provider.unreadDividerIndex,
            myId: _myId,
            highlightMessageId: _highlightMessageId,
            editingMessageId: _editingMessageId,
            editMessageController: _editMessageController,
            messageKeys: _messageKeys,
            conversation: widget.conversation,
            convThemeId: _convThemeId,
            onEditMessage: _handleEditMessage,
            onDeleteMessage: _handleDeleteMessage,
            onCopyMessage: _handleCopyMessage,
            onPinMessage: _handlePinMessage,
            onForwardMessage: _handleForwardMessage,
            onReplyMessage: _handleReplyMessage,
            onReactToMessage: _handleReactToMessage,
            onCancelEdit: _cancelEdit,
            onSaveEditedMessage: _saveEditedMessage,
            onScrollToMessage: _scrollToMessage,
            onDownloadFile: _confirmFileDownload,
          );
        },
      ),
    );
  }

  /// Confirm file download
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

    try {
      await downloadFile(url, fileName);
      if (mounted) {
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

  /// Handles edit message
  void _handleEditMessage(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _editMessageController.text = message.body;
    });
  }

  /// Cancel edit
  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editMessageController.clear();
    });
  }

  /// Saves edited message
  Future<void> _saveEditedMessage(Message message) async {
    final newText = _editMessageController.text.trim();
    if (newText.isEmpty) return;

    _cancelEdit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagem editada'),
        duration: Duration(seconds: 1),
      ),
    );

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
    }
  }

  /// Handles delete message
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
      }
    }
  }

  /// Handles copy message
  void _handleCopyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.body));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensagem copiada')));
  }

  /// Handles pin message
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

  /// Handles forward message
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

  /// Handles reply message
  void _handleReplyMessage(Message message) {
    context.read<MessagesProvider>().startReply(message);
    _focusNode.requestFocus();
  }

  /// Handles react to message
  void _handleReactToMessage(Message message, String reaction) {
    if (_myId == null) return;
    context.read<MessagesProvider>().toggleReaction(
      messageId: message.id,
      userId: _myId!,
      reaction: reaction,
    );
  }

  /// Builds input area
  Widget _buildInputArea(ThemeData theme) {
    // Block UI during loading - when conversation details are null, user cannot send
    final canSend = _conversationDetails == null
        ? false
        : canUserSendMessage(
            _conversationDetails!.settings,
            _conversationDetails!.amAdmin,
          );
    final permissionMessage = getPermissionMessage(
      _conversationDetails?.settings,
      _conversationDetails?.amAdmin ?? false,
    );

    if (!canSend && permissionMessage.isNotEmpty) {
      // Show disabled input with permission message
      return Container(
        padding: const EdgeInsets.all(12),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  permissionMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MessageInputBar(
      messageController: _messageController,
      focusNode: _focusNode,
      isRecording: _isRecording,
      hasText: _hasText,
      canSend: canSend,
      onShowAttachmentOptions: canSend ? _showAttachmentOptions : () {},
      onSendMessage: canSend ? _sendMessage : () {},
      onStartRecording: canSend ? () => _startRecording() : () {},
      onDiscardRecording: canSend ? () => _discardRecording() : () {},
      onStopAndSendRecording: canSend ? () => _stopAndSendRecording() : () {},
    );
  }
}
