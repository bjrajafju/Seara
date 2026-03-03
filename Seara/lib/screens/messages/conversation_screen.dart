import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/providers/messages_provider.dart';
import 'package:seara/services/auth_service.dart';

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

  int? _myId;
  late MessagesProvider _messagesProvider;

  @override
  void initState() {
    super.initState();
    _messagesProvider = context.read<MessagesProvider>();
    _init();
  }

  Future<void> _init() async {
    _myId = await AuthService.getUserId();

    if (!mounted) return;

    final provider = context.read<MessagesProvider>();
    await provider.loadMessages(widget.conversation.id);

    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
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

    final success = await context.read<MessagesProvider>().sendMessage(
      conversationId: widget.conversation.id,
      userId: _myId!,
      body: text,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null || _myId == null) return;
    if (!mounted) return;

    try {
      final bytes = await file.readAsBytes();
      final fileName = file.name.isNotEmpty ? file.name : 'image.jpg';

      final success = await _messagesProvider.sendImageMessage(
        conversationId: widget.conversation.id,
        userId: _myId!,
        fileBytes: bytes,
        fileName: fileName,
      );

      if (!mounted) return;

      if (success) {
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Erro ao enviar imagem.")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Erro ao ler imagem.")));
    }
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
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.attachment!,
                      width: 240,
                      fit: BoxFit.cover,
                    ),
                  ),
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
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.attachment!,
                      width: 240,
                      fit: BoxFit.cover,
                    ),
                  ),
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
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                color: theme.colorScheme.onSurface,
                onPressed: _pickImage,
              ),
              Expanded(child: _buildMessageField(theme)),
              const SizedBox(width: 8),
              Consumer<MessagesProvider>(
                builder: (context, provider, _) {
                  return IconButton(
                    icon: provider.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    color: theme.colorScheme.primary,
                    onPressed: provider.isSending ? null : _sendMessage,
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
