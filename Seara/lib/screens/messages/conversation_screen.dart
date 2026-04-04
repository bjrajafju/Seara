import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/screens/messages/attachment_preview_screen.dart';
import 'package:seara/screens/messages/image_lightbox_screen.dart';
import 'package:seara/screens/messages/video_lightbox_screen.dart';
import 'package:seara/screens/messages/widgets/audio_message_widget.dart';
import 'package:seara/services/auth_service.dart';

// Import condicional: usa web em browser, stub em mobile
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

// Intervalo maximo em minutos para agrupar mensagens do mesmo utilizador
const int _kGroupingMinutes = 5;

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
  void initState() {
    super.initState();
    _messagesProvider = context.read<MessagesProvider>();
    _messageController.addListener(_onTextChanged);
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

          final messages = provider.messages;

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMe = message.userId == _myId;
              final isFirst = _isFirstInGroup(messages, index);
              final isLast = _isLastInGroup(messages, index);

              return isMe
                  ? _buildMyMessage(theme, message, isFirst, isLast)
                  : _buildOtherMessage(theme, message, isFirst, isLast);
            },
          );
        },
      ),
    );
  }

  Widget _buildAttachmentContent(ThemeData theme, Message message) {
    switch (message.attachmentType) {
      // ── Imagem ────────────────────────────────────────────────────────
      case AttachmentType.image:
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black,
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

      // ── Vídeo ─────────────────────────────────────────────────────────
      case AttachmentType.video:
        return _VideoThumbnailWidget(
          url: message.attachment!,
          fileName: message.attachmentName,
        );

      // ── Áudio ─────────────────────────────────────────────────────────
      case AttachmentType.audio:
        return AudioMessageWidget(url: message.attachment!);

      // ── Ficheiro genérico ─────────────────────────────────────────────
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
        final response = await http.get(Uri.parse(url));
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

    return Padding(
      // Mais espaco antes do primeiro de um grupo, menos entre mensagens do mesmo grupo
      padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 4 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
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
          Expanded(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
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
                      if (message.body.isNotEmpty)
                        SelectableText(
                          message.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      if (message.attachment != null) ...[
                        if (message.body.isNotEmpty) const SizedBox(height: 6),
                        _buildAttachmentContent(theme, message),
                      ],
                    ],
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
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
                if (message.body.isNotEmpty)
                  SelectableText(
                    message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                if (message.attachment != null) ...[
                  if (message.body.isNotEmpty) const SizedBox(height: 6),
                  _buildAttachmentContent(theme, message),
                ],
              ],
            ),
          ),
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
            if (_hasText) {
              return IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
                onPressed: _sendMessage,
              );
            }
            if (kIsWeb) {
              return Tooltip(
                message: "Gravacao disponivel apenas na app mobile",
                child: IconButton(
                  icon: const Icon(Icons.mic_off_rounded),
                  color: theme.colorScheme.onSurface.withAlpha(80),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Gravacao de audio nao disponivel no browser.",
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
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            VideoLightboxScreen(videoUrl: url, fileName: fileName),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLightbox(context),
      child: Container(
        width: 220,
        height: 124,
        decoration: BoxDecoration(
          color: Colors.black87,
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
                color: Colors.black.withAlpha(140),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white70,
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
