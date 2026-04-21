import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../services/messages_service.dart';
import '../../providers/messages_provider.dart';
import 'conversation_screen.dart';

class ForwardMessageScreen extends StatefulWidget {
  final Message message;
  final int myId;

  const ForwardMessageScreen({
    super.key,
    required this.message,
    required this.myId,
  });

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final MessagesService _service = MessagesService();
  List<Conversation> _conversations = [];
  final Set<int> _selectedIds = {};
  String _searchQuery = "";
  bool _isSending = false;
  bool _isLoading = true;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _loadConversations();
  }

  /// Loads conversations
  Future<void> _loadConversations() async {
    try {
      final convs = await _service.fetchConversations(widget.myId);
      if (mounted) {
        setState(() {
          _conversations = convs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((c) {
      final name = c.isGroup
          ? c.name ?? "Grupo"
          : c.participants
                    .where((p) => p.id != widget.myId)
                    .firstOrNull
                    ?.username ??
                "Chat";
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  /// Toggles selection
  void _toggleSelection(int convId) {
    setState(() {
      if (_selectedIds.contains(convId)) {
        _selectedIds.remove(convId);
      } else {
        _selectedIds.add(convId);
      }
    });
  }

  /// Handles forward
  Future<void> _handleForward() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isSending = true);

    final prov = context.read<MessagesProvider>();
    bool hasError = false;

    for (final id in _selectedIds) {
      try {
        await prov.sendMessage(
          conversationId: id,
          userId: widget.myId,
          body: widget.message.body,
          attachment: widget.message.attachment,
          attachmentType: widget.message.attachmentType == AttachmentType.image
              ? "image/jpeg"
              : widget.message.attachmentType == AttachmentType.video
              ? "video/mp4"
              : widget.message.attachmentType == AttachmentType.audio
              ? "audio/mp4"
              : widget.message.attachmentType == AttachmentType.file
              ? "application/octet-stream"
              : null,
          attachmentName: widget.message.attachmentName,
          isForwarded: true,
        );
      } catch (e) {
        hasError = true;
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
      if (hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Algumas mensagens nao puderam ser reencaminhadas."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mensagem reencaminhada com sucesso.")),
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final convs = _filteredConversations;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Reencaminhar"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Procurar conversa...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : convs.isEmpty
                ? const Center(child: Text("Nenhuma conversa encontrada."))
                : ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (ctx, i) {
                      final c = convs[i];
                      final name = c.isGroup
                          ? c.name ?? "Grupo"
                          : c.participants
                                    .where((p) => p.id != widget.myId)
                                    .firstOrNull
                                    ?.username ??
                                "Chat";
                      final avatar = c.isGroup && c.image != null
                          ? c.image!
                          : c.participants
                                    .where((p) => p.id != widget.myId)
                                    .firstOrNull
                                    ?.avatarUrl ??
                                "https://ui-avatars.com/api/?name=$name";

                      final isSelected = _selectedIds.contains(c.id);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(avatar),
                        ),
                        title: Text(name),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(c.id),
                          activeColor: theme.colorScheme.primary,
                        ),
                        onTap: () => _toggleSelection(c.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSending ? null : _handleForward,
              icon: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text("Reencaminhar (${_selectedIds.length})"),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }
}
