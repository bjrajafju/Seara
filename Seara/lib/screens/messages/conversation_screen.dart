import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seara/models/conversation_model.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversation});
  final Conversation conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  // APP BAR
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
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.network(
              'https://images.unsplash.com/photo-1633332755192-727a05c4013d',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'User/Group Name',
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

  // MESSAGES LIST
  Widget _buildMessagesList(ThemeData theme) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        reverse: true,
        children: [_buildOtherMessage(theme), _buildMyMessage(theme)],
      ),
    );
  }

  // OTHER MESSAGE
  Widget _buildOtherMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 1),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              'https://images.unsplash.com/photo-1521572267360-ee0c2909d518',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              'Texto da mensagem de outra pessoa sem imagem',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // MY MESSAGE
  Widget _buildMyMessage(ThemeData theme) {
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
                SelectableText(
                  'Texto da minha mensagem com imagem',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://picsum.photos/300/200',
                    width: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              'https://images.unsplash.com/photo-1633332755192-727a05c4013d',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  // INPUT AREA
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
                onPressed: () {},
              ),
              Expanded(child: _buildMessageField(theme)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MESSAGE FIELD
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

  // SEND
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    debugPrint('Mensagem enviada: ${_messageController.text}');
    _messageController.clear();
  }
}
