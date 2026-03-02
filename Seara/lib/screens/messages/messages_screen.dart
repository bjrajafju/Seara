import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/providers/theme_provider.dart';
import 'package:seara/screens/messages/conversation_screen.dart';
import 'package:seara/screens/messages/new_conversation_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/messages_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MessagesService _messagesService = MessagesService();

  List<Conversation> _conversations = [];
  bool _isLoading = true;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      int? myId = await AuthService.getUserId();
      if (myId == null) return;
      final data = await _messagesService.fetchConversations(myId);

      setState(() {
        _conversations = data;
        _isLoading = false;
        _myId = myId;
      });
    } catch (e) {
      print(e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  // SEARCH BAR
  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: "Pesquisar...",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget _buildResultsHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            "Resultados:",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "24",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  // MESSAGE ITEM
  Widget _buildMessageItem(ThemeData theme, Conversation conversation) {
    final lastMessage = conversation.messages.isNotEmpty
        ? conversation.messages.first
        : null;

    final otherUser = conversation.participants
        .where((u) => u.id != _myId)
        .toList();

    final displayName = conversation.isGroup
        ? conversation.name ?? "Grupo"
        : (otherUser.isNotEmpty ? otherUser.first.username : "User");

    final displayAvatar = otherUser.isNotEmpty
        ? otherUser.first.avatarUrl
        : "https://ui-avatars.com/api/?name=User";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: conversation),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(displayAvatar),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage?.body ?? "Sem mensagens",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (lastMessage != null)
              Text(
                lastMessage.createdAt.toLocal().toString().split(" ")[0],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // LIST OF MESSAGES
  Widget _buildMessagesList(ThemeData theme) {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_conversations.isEmpty) {
      return const Expanded(child: Center(child: Text("Sem conversas ainda.")));
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
        itemBuilder: (_, index) =>
            _buildMessageItem(theme, _conversations[index]),
      ),
    );
  }

  // NEW MESSAGE BUTTON
  Widget _buildNewMessageButton(ThemeData theme) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewConversationScreen()),
        );
      },
      backgroundColor: theme.colorScheme.primary,
      elevation: 8,
      child: Icon(
        Icons.add_rounded,
        color: theme.colorScheme.onPrimary,
        size: 24,
      ),
    );
  }

  // BODY
  Widget _buildBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(theme),
        _buildResultsHeader(theme),
        const SizedBox(height: 8),
        _buildMessagesList(theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: Text(
            'Mensagens',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0.5,
        ),
        floatingActionButton: _buildNewMessageButton(theme),
        body: SafeArea(child: _buildBody(theme)),
      ),
    );
  }
}
