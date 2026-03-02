import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seara/models/profile_model.dart';
import 'package:seara/providers/theme_provider.dart';
import 'package:seara/screens/messages/conversation_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/messages_service.dart';
import 'package:seara/services/profile_service.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final MessagesService _messagesService = MessagesService();

  List<Profile> _users = [];
  Set<int> _selectedUsers = {};
  bool _isLoading = true;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final users = await ProfileService.getAllUsers();
    int? myId = await AuthService.getUserId();
    if (myId == null) return;

    setState(() {
      _users = users
          .map((u) => Profile.fromJson({...u, "avatar_url": u['avatar']}))
          .where((u) => u.id != myId)
          .toList();
      _isLoading = false;
      _myId = myId;
    });
  }

  Future<void> _createConversation() async {
    if (_selectedUsers.isEmpty) return;
    int? myId = _myId;
    if (myId == null) return;

    final conversation = await _messagesService.createConversation(
      creatorId: myId,
      participantIds: _selectedUsers.toList(),
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildAppBar(theme),
        floatingActionButton: _buildFloatingButton(theme),
        body: SafeArea(child: _buildBody(theme)),
      ),
    );
  }

  // App bar
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(100),
      child: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    'Create conversation',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Floating button
  Widget _buildFloatingButton(ThemeData theme) {
    return FloatingActionButton(
      onPressed: _createConversation,
      backgroundColor: theme.colorScheme.primary,
      child: Icon(Icons.check, color: theme.colorScheme.onPrimary),
    );
  }

  // Body
  Widget _buildBody(ThemeData theme) {
    return Column(
      children: [
        _buildSearchField(theme),
        _buildResultsHeader(theme),
        const SizedBox(height: 8),
        _buildUsersList(theme),
      ],
    );
  }

  // Search Bar
  Widget _buildSearchField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          labelText: 'Search...',
          prefixIcon: Icon(
            Icons.search_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // Results header
  Widget _buildResultsHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12),
      child: Row(
        children: [
          Text(
            'Resultados:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '24',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Users list
  Widget _buildUsersList(ThemeData theme) {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final selected = _selectedUsers.contains(user.id);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedUsers.remove(user.id);
                } else {
                  _selectedUsers.add(user.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(user.avatarUrl),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.username,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
