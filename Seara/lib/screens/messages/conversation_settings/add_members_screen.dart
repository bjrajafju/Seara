import 'package:flutter/material.dart';
import 'package:seara/models/auxiliar/user_with_relationship_model.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/services/profile/profile_service.dart';

class AddMembersScreen extends StatefulWidget {
  const AddMembersScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.existingMemberIds,
  });

  final int conversationId;
  final int userId;
  final Set<int> existingMemberIds;

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserWithRelationship> _allUsers = [];
  List<UserWithRelationship> _filteredUsers = [];
  Set<int> _selectedUsers = {};
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearch);
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  /// Loads users
  Future<void> _loadUsers() async {
    try {
      final users = await ProfileService.getUsersWithRelationship(
        widget.userId,
      );
      final available = users
          .where((u) => u.id != 0 && !widget.existingMemberIds.contains(u.id))
          .toList();

      if (!mounted) return;
      setState(() {
        _allUsers = available;
        _filteredUsers = available;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Handles search
  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
      return;
    }
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        return u.username.toLowerCase().contains(q) ||
            u.name.toLowerCase().contains(q);
      }).toList();
    });
  }

  /// Add selected
  Future<void> _addSelected() async {
    if (_selectedUsers.isEmpty || _isAdding) return;
    setState(() => _isAdding = true);

    try {
      await ConversationSettingsService.addMembers(
        widget.conversationId,
        widget.userId,
        _selectedUsers.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'Adicionar membros',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        floatingActionButton: _selectedUsers.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _isAdding ? null : _addSelected,
                backgroundColor: theme.colorScheme.primary,
                icon: _isAdding
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.onPrimary,
                      ),
                label: Text(
                  'Adicionar (${_selectedUsers.length})',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Pesquisar utilizadores...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum utilizador disponível.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final selected = _selectedUsers.contains(user.id);

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: NetworkImage(
                                        user.avatarUrl,
                                      ),
                                    ),
                                    if (selected)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: theme.colorScheme.primary
                                                .withAlpha(180),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.username,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (user.name.isNotEmpty)
                                        Text(
                                          user.name,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(120),
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
