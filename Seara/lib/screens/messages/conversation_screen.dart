import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/messages/attachment_preview_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:video_player/video_player.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversation});
  final Conversation conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  int? _myId;
  late MessagesProvider _messagesProvider;
  bool _isRecording = false;
  bool _hasText = false;

  @override
  @override
  void initState() {
    super.initState();
    _messagesProvider = context.read<MessagesProvider>();
    _messageController.addListener(_onTextChanged);
    _initFilePicker();
    _init();
  }

  void _initFilePicker() {
    // Garantir que o FilePicker esta inicializado no web
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

  Future<void> _init() async {
    _myId = await AuthService.getUserId();
    if (!mounted) return;
    await _messagesProvider.loadMessages(widget.conversation.id);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _messagesProvider.clear();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == null) return;
    _messageController.clear();

    final success = await _messagesProvider.sendMessage(
      conversationId: widget.conversation.id,
      userId: _myId!,
      body: text,
    );

    if (success) _scrollToBottom();
  }

  // Abre bottom sheet com opcoes de anexo
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

    // Crop so disponivel para imagens em mobile
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
    } else if (['mp3', 'm4a', 'wav', 'ogg', 'aac'].contains(ext)) {
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
    );

    if (success && mounted) _scrollToBottom();
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Erro ao enviar ficheiro.")));
    }
  }

  // Gravar audio
  Future<void> _startRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Gravacao de audio nao disponivel no browser. Use a app mobile.",
          ),
        ),
      );
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permissao de microfone negada.")),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    setState(() => _isRecording = true);
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording || kIsWeb) return;

    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (path == null || _myId == null) return;

    final file = File(path);
    final bytes = await file.readAsBytes();
    final fileName = "audio_${DateTime.now().millisecondsSinceEpoch}.m4a";

    if (!mounted) return;

    await _openPreviewAndSend(
      bytes: bytes,
      fileName: fileName,
      mimeType: "audio/mp4",
      type: PreviewType.audio,
    );
  }

  Future<void> _discardRecording() async {
    if (!_isRecording) return;
    await _recorder.cancel();
    setState(() => _isRecording = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(theme),
        body: Column(
          children: [_buildMessagesList(theme), _buildInputArea(theme)],
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
          IconButton(
            icon: const Icon(Icons.settings_sharp),
            color: theme.colorScheme.onPrimary,
            onPressed: () {},
          ),
        ],
      ),
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
                "Sem mensagens ainda. Diz ola!",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            itemCount: provider.messages.length,
            itemBuilder: (context, index) {
              final message = provider.messages[index];
              final isMe = message.userId == _myId;
              return isMe
                  ? _buildMyMessage(theme, message)
                  : _buildOtherMessage(theme, message);
            },
          );
        },
      ),
    );
  }

  Widget _buildAttachmentContent(ThemeData theme, Message message) {
    switch (message.attachmentType) {
      case AttachmentType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.attachment!,
            width: 240,
            fit: BoxFit.cover,
          ),
        );

      case AttachmentType.video:
        return _VideoMessageWidget(url: message.attachment!);

      case AttachmentType.audio:
        return _AudioMessageWidget(url: message.attachment!);

      case AttachmentType.file:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded, size: 32),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message.attachmentName ?? "Ficheiro",
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      case AttachmentType.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOtherMessage(ThemeData theme, Message message) {
    final avatarUrl =
        message.senderAvatar ??
        "https://ui-avatars.com/api/?name=${message.senderUsername ?? 'U'}";

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 1),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.body.isNotEmpty)
                  SelectableText(
                    message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                if (message.attachment != null) ...[
                  if (message.body.isNotEmpty) const SizedBox(height: 8),
                  _buildAttachmentContent(theme, message),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyMessage(ThemeData theme, Message message) {
    final avatarUrl =
        message.senderAvatar ??
        "https://ui-avatars.com/api/?name=${message.senderUsername ?? 'Me'}";

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 1),
      color: theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.body.isNotEmpty)
                  SelectableText(
                    message.body,
                    style: theme.textTheme.bodyMedium,
                  ),
                if (message.attachment != null) ...[
                  if (message.body.isNotEmpty) const SizedBox(height: 8),
                  _buildAttachmentContent(theme, message),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
        ],
      ),
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
              : _buildNormalInput(theme),
        ),
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
            // Se tem texto, mostra botao de enviar. Se nao, mostra microfone.
            if (_hasText) {
              return IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
                onPressed: _sendMessage,
              );
            }
            // No browser o microfone nao e suportado, mostrar botao desativado com tooltip
            if (kIsWeb) {
              return Tooltip(
                message: "Gravação disponível apenas na app mobile",
                child: IconButton(
                  icon: const Icon(Icons.mic_off_rounded),
                  color: theme.colorScheme.onSurface.withAlpha(80),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Gravação de áudio nao disponível no browser.",
                        ),
                      ),
                    );
                  },
                ),
              );
            }
            return GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopAndSendRecording(),
              child: IconButton(
                icon: const Icon(Icons.mic_rounded),
                color: theme.colorScheme.primary,
                onPressed: null,
              ),
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
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
        // No browser mostra botao de parar
        if (kIsWeb)
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
      textInputAction: TextInputAction.send,
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
      onFieldSubmitted: (_) => _sendMessage(),
    );
  }
}

// Widget de video inline nas mensagens
class _VideoMessageWidget extends StatefulWidget {
  const _VideoMessageWidget({required this.url});
  final String url;

  @override
  State<_VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<_VideoMessageWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() => _initialized = true);
        });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return GestureDetector(
        onTap: () => launchUrl(widget.url),
        child: Container(
          width: 240,
          height: 135,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 8),
              Text(
                "Ver video",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        width: 240,
        height: 135,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void launchUrl(String url) {
    // Para abrir o link no browser
  }
}

// Widget de audio inline nas mensagens
class _AudioMessageWidget extends StatefulWidget {
  const _AudioMessageWidget({required this.url});
  final String url;

  @override
  State<_AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<_AudioMessageWidget> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _initialized = false;

  Future<void> _initPlayer() async {
    if (_initialized) return;
    _initialized = true;

    final player = AudioPlayer();

    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    if (mounted) setState(() => _player = player);
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    await _initPlayer();
    final player = _player;
    if (player == null) return;

    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play(UrlSource(widget.url));
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 32,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: theme.colorScheme.primary,
            ),
            onPressed: _toggle,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.outline.withAlpha(60),
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_fmt(_position)} / ${_fmt(_duration)}",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
