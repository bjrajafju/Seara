import 'package:flutter/material.dart';
import 'package:seara/screens/messages/conversation_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/messages_service.dart';
import 'package:seara/services/profile_service.dart';
import 'package:seara/models/auxiliar/user_with_relationship_model.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final MessagesService _messagesService = MessagesService();

  List<UserWithRelationship> _allUsers = [];
  List<UserWithRelationship> _filteredUsers = [];
  Set<int> _selectedUsers = {};
  bool _isLoading = true;
  bool _isCreating = false;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    int? myId = await AuthService.getUserId();
    if (myId == null) return;

    try {
      final users = await ProfileService.getUsersWithRelationship(myId);

      if (!mounted) return;

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
        _myId = myId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
      return;
    }

    final filtered = _allUsers.where((user) {
      return user.username.toLowerCase().contains(query) ||
          user.name.toLowerCase().contains(query);
    }).toList();

    // Manter ordenacao por relacao dentro dos resultados filtrados
    filtered.sort((a, b) => a.sortWeight.compareTo(b.sortWeight));

    setState(() => _filteredUsers = filtered);
  }

  Future<void> _createConversation() async {
    if (_selectedUsers.isEmpty || _myId == null || _isCreating) return;

    setState(() => _isCreating = true);

    try {
      final conversation = await _messagesService.createConversation(
        creatorId: _myId!,
        participantIds: _selectedUsers.toList(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Erro ao criar conversa.")));
    }
  }

  String? _getRelationshipLabel(UserWithRelationship user) {
    if (user.isMutual) return "Mutuos";
    if (user.followsMe) return "Segue-te";
    if (user.iFollow) return "Segues";
    return null;
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
                    'Nova conversa',
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

  Widget _buildFloatingButton(ThemeData theme) {
    if (_selectedUsers.isEmpty) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: _isCreating ? null : _createConversation,
      backgroundColor: theme.colorScheme.primary,
      icon: _isCreating
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Icon(Icons.check_rounded, color: theme.colorScheme.onPrimary),
      label: Text(
        _selectedUsers.length == 1
            ? "Abrir conversa"
            : "Criar grupo (${_selectedUsers.length})",
        style: TextStyle(color: theme.colorScheme.onPrimary),
      ),
    );
  }

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

  Widget _buildSearchField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: "Pesquisar utilizadores...",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
          ),
          prefixIcon: Icon(
            Icons.search_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => _searchController.clear(),
                )
              : null,
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
            '${_filteredUsers.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(ThemeData theme) {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_filteredUsers.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            "Nenhum utilizador encontrado.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final selected = _selectedUsers.contains(user.id);
          final label = _getRelationshipLabel(user);

          return InkWell(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedUsers.remove(user.id);
                } else {
                  _selectedUsers.add(user.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Avatar com overlay de selecao
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(user.avatarUrl),
                      ),
                      if (selected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withAlpha(180),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Nome e label de relacao
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (user.name.isNotEmpty)
                          Text(
                            user.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Tag de relacao
                  if (label != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
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
