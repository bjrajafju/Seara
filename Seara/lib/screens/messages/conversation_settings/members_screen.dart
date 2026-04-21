import 'package:flutter/material.dart';
import 'package:seara/models/conversation_settings_model.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/screens/messages/conversation_settings/add_members_screen.dart';
import 'package:seara/screens/profile/profile_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.details,
    required this.isGroup,
  });

  final int conversationId;
  final int userId;
  final ConversationDetails details;
  final bool isGroup;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late List<ConversationMember> _members;
  late bool _amAdmin;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _members = widget.details.members.where((m) => m.id != 0).toList();
    _amAdmin = widget.details.amAdmin;
  }

  /// Reload
  Future<void> _reload() async {
    try {
      final details = await ConversationSettingsService.getDetails(
        widget.conversationId,
        widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _members = details.members;
        _amAdmin = details.amAdmin;
      });
    } catch (_) {}
  }

  /// Navigates to the selected user profile
  void _openProfile(ConversationMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => member.id == widget.userId
            ? const ProfileScreen()
            : ProfileScreen(userId: member.id),
      ),
    );
  }

  /// Shows member options
  void _showMemberOptions(ConversationMember member) {
    if (!_amAdmin || member.id == widget.userId) return;
    if (member.isCreator) return;

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(member.avatarUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.username,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            member.isAdmin ? 'Admin' : 'Membro',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.person_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Ver perfil'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openProfile(member);
                },
              ),
              if (_amAdmin && !member.isCreator)
                ListTile(
                  leading: Icon(
                    member.isAdmin
                        ? Icons.person_remove_rounded
                        : Icons.admin_panel_settings_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    member.isAdmin ? 'Remover admin' : 'Tornar admin',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleRole(member);
                  },
                ),
              if (_amAdmin && !member.isCreator)
                ListTile(
                  leading: Icon(
                    Icons.remove_circle_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Remover do grupo',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeMember(member);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggles role
  Future<void> _toggleRole(ConversationMember member) async {
    final newRole = member.isAdmin ? 0 : 1;
    try {
      await ConversationSettingsService.updateMemberRole(
        widget.conversationId,
        member.id,
        widget.userId,
        newRole,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newRole == 1
                ? '${member.username} é agora admin'
                : '${member.username} já não é admin',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  /// Remove member
  Future<void> _removeMember(ConversationMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover membro'),
        content: Text(
          'Tens a certeza que queres remover ${member.username} do grupo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ConversationSettingsService.removeMember(
        widget.conversationId,
        member.id,
        widget.userId,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  /// Opens add members
  void _openAddMembers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMembersScreen(
          conversationId: widget.conversationId,
          userId: widget.userId,
          existingMemberIds: _members.map((m) => m.id).toSet(),
        ),
      ),
    );
    _reload();
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Membros',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (widget.isGroup && _amAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              onPressed: _openAddMembers,
              tooltip: 'Adicionar membros',
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          final isMe = member.id == widget.userId;
          final canRemove =
              _amAdmin && !isMe && !member.isCreator && widget.isGroup;

          return InkWell(
            onTap: () => _openProfile(member),
            onLongPress: widget.isGroup
                ? () => _showMemberOptions(member)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(member.avatarUrl),
                      ),
                      if (member.isCreator)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: theme.colorScheme.onTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.username,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe)
                              Text(
                                ' (tu)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    120,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (member.name.isNotEmpty)
                          Text(
                            member.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (member.isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: member.isCreator
                              ? theme.colorScheme.tertiaryContainer
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.isCreator ? 'Criador' : 'Admin',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: member.isCreator
                                ? theme.colorScheme.onTertiaryContainer
                                : theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (canRemove)
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.error.withAlpha(160),
                      ),
                      onPressed: () => _removeMember(member),
                      tooltip: 'Remover',
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
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
