import 'package:flutter/material.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/conversation_settings_model.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/screens/messages/conversation_settings/members_screen.dart';
import 'package:seara/screens/messages/conversation_settings/notifications_screen.dart';
import 'package:seara/screens/messages/conversation_settings/search_messages_screen.dart';
import 'package:seara/screens/messages/conversation_settings/admin_settings_screen.dart';
import 'package:seara/screens/messages/conversation_settings/theme_screen.dart';
import 'package:seara/screens/messages/conversation_settings/ephemeral_messages_screen.dart';
import 'package:seara/screens/messages/conversation_settings/edit_group_screen.dart';
import 'package:seara/screens/messages/conversation_settings/call_screen.dart';
import 'package:seara/screens/profile/profile_screen.dart';
import 'package:seara/screens/messages/widgets/conversation_details/conversation_danger_zone.dart';
import 'package:seara/screens/messages/widgets/conversation_details/conversation_info_sliver.dart';
import 'package:seara/screens/messages/widgets/conversation_details/conversation_media_sections.dart';
import 'package:seara/screens/messages/widgets/conversation_details/conversation_quick_actions.dart';
import 'package:seara/screens/messages/widgets/conversation_details/conversation_settings_list.dart';

class ConversationDetailsScreen extends StatefulWidget {
  const ConversationDetailsScreen({
    super.key,
    required this.conversation,
    required this.myId,
  });

  final Conversation conversation;
  final int myId;

  @override
  /// Creates the state object for this screen
  State<ConversationDetailsScreen> createState() =>
      _ConversationDetailsScreenState();
}

class _ConversationDetailsScreenState extends State<ConversationDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ConversationDetails? _details;
  bool _isLoading = true;
  String? _error;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetails();
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Loads details
  Future<void> _loadDetails() async {
    try {
      final details = await ConversationSettingsService.getDetails(
        widget.conversation.id,
        widget.myId,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _displayName {
    if (widget.conversation.isGroup) {
      return _details?.name ?? widget.conversation.name ?? 'Grupo';
    }
    final other = widget.conversation.participants
        .where((u) => u.id != widget.myId)
        .toList();
    return other.isNotEmpty ? other.first.name : 'Utilizador';
  }

  String get _displayAvatar {
    if (widget.conversation.isGroup && _details?.image != null) {
      return _details!.image!;
    }
    final other = widget.conversation.participants
        .where((u) => u.id != widget.myId)
        .toList();
    if (other.isNotEmpty) return other.first.avatarUrl;
    return 'https://ui-avatars.com/api/?name=Group';
  }

  int? get _otherUserId {
    if (widget.conversation.isGroup) return null;
    final other = widget.conversation.participants
        .where((u) => u.id != widget.myId)
        .toList();
    return other.isNotEmpty ? other.first.id : null;
  }

  /// Toggles pin
  Future<void> _togglePin() async {
    try {
      final newState = await ConversationSettingsService.togglePin(
        widget.conversation.id,
        widget.myId,
      );
      if (!mounted) return;
      setState(() {
        _details = ConversationDetails(
          id: _details!.id,
          name: _details!.name,
          isGroup: _details!.isGroup,
          image: _details!.image,
          description: _details!.description,
          members: _details!.members,
          settings: _details!.settings,
          myRole: _details!.myRole,
          isCreator: _details!.isCreator,
          isPinned: newState,
          notification: _details!.notification,
          createdAt: _details!.createdAt,
          updatedAt: _details!.updatedAt,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'Conversa fixada' : 'Conversa desfixada'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao fixar/desfixar conversa.')),
      );
    }
  }

  /// Danger action
  Future<void> _dangerAction() async {
    final isGroup = widget.conversation.isGroup;
    final isCreator = _details?.isCreator ?? false;

    String title;
    String content;
    String actionLabel;

    if (isGroup && isCreator) {
      title = 'Eliminar grupo';
      content =
          'Tens a certeza que queres eliminar este grupo? Esta ação é irreversível.';
      actionLabel = 'Eliminar';
    } else if (isGroup) {
      title = 'Sair do grupo';
      content = 'Tens a certeza que queres sair deste grupo?';
      actionLabel = 'Sair';
    } else {
      title = 'Arquivar conversa';
      content = 'A conversa será arquivada e ocultada.';
      actionLabel = 'Arquivar';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (isGroup && isCreator) {
        await ConversationSettingsService.deleteConversation(
          widget.conversation.id,
          widget.myId,
        );
      } else {
        await ConversationSettingsService.leaveConversation(
          widget.conversation.id,
          widget.myId,
        );
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar detalhes',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadDetails();
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(theme),
            SliverToBoxAdapter(child: _buildActionButtons(theme)),
            SliverToBoxAdapter(
              child: Divider(
                height: 1,
                color: theme.dividerColor.withAlpha(60),
              ),
            ),
            SliverToBoxAdapter(child: _buildSettingsSections(theme)),
            SliverToBoxAdapter(
              child: Divider(
                height: 1,
                color: theme.dividerColor.withAlpha(60),
              ),
            ),
            SliverToBoxAdapter(child: _buildDangerZone(theme)),
            SliverToBoxAdapter(
              child: Divider(
                height: 1,
                color: theme.dividerColor.withAlpha(60),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: ConversationStickyTabBarDelegate(
                tabBar: _buildTabBar(theme),
                color: theme.colorScheme.surface,
              ),
            ),
          ],
          body: _buildTabContent(theme),
        ),
      ),
    );
  }

  /// Builds sliver app bar
  Widget _buildSliverAppBar(ThemeData theme) {
    final membersCount =
        _details?.members.length ?? widget.conversation.participants.length;
    final username = widget.conversation.participants
        .where((u) => u.id != widget.myId)
        .firstOrNull
        ?.username;
    return ConversationInfoSliver(
      isGroup: widget.conversation.isGroup,
      isAdmin: _details?.amAdmin ?? false,
      displayAvatar: _displayAvatar,
      displayName: _displayName,
      membersLabel: widget.conversation.isGroup
          ? '$membersCount membros'
          : null,
      description: _details?.description,
      usernameLabel: !widget.conversation.isGroup ? '@${username ?? ''}' : null,
      canEditBio: _canEditBio,
      onBack: () => Navigator.pop(context),
      onOpenProfile: !widget.conversation.isGroup && _otherUserId != null
          ? () => _openProfile(_otherUserId!)
          : null,
      onOpenEditGroup:
          widget.conversation.isGroup && (_details?.amAdmin ?? false)
          ? _openEditGroup
          : null,
      onEditDescription: _editDescription,
    );
  }

  /// Builds action buttons
  Widget _buildActionButtons(ThemeData theme) {
    final actions = [
      ConversationQuickActionItem(
        icon: Icons.search_rounded,
        label: 'Pesquisar',
        onTap: () => _openSearch(),
      ),
    ];
    return ConversationQuickActions(actions: actions);
  }

  /// Builds settings sections
  Widget _buildSettingsSections(ThemeData theme) {
    final items = <ConversationSettingsItem>[
      if (widget.conversation.isGroup)
        ConversationSettingsItem(
          icon: Icons.group_outlined,
          title: 'Membros',
          subtitle: '${_details?.members.length ?? 0} membros',
          onTap: () => _openMembers(),
        ),
      if (!widget.conversation.isGroup && _otherUserId != null)
        ConversationSettingsItem(
          icon: Icons.person_outlined,
          title: 'Ver perfil',
          onTap: () => _openProfile(_otherUserId!),
        ),
      ConversationSettingsItem(
        icon: Icons.notifications_outlined,
        title: 'Notificações',
        subtitle: _details?.notification.muteLabel ?? 'Ativadas',
        onTap: () => _openNotifications(),
      ),
      ConversationSettingsItem(
        icon: Icons.palette_outlined,
        title: 'Tema da conversa',
        subtitle: _details?.settings?.themeLabel,
        onTap: () => _openTheme(),
      ),
      ConversationSettingsItem(
        icon: Icons.timer_outlined,
        title: 'Mensagens temporárias',
        subtitle: _details?.settings?.ephemeralLabel ?? 'Desativado',
        onTap: () => _openEphemeral(),
      ),
      if (widget.conversation.isGroup && (_details?.amAdmin ?? false))
        ConversationSettingsItem(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Administração',
          subtitle: 'Permissões e cargos',
          onTap: () => _openAdminSettings(),
        ),
      ConversationSettingsItem(
        icon: _details?.isPinned == true
            ? Icons.push_pin_rounded
            : Icons.push_pin_outlined,
        title: _details?.isPinned == true
            ? 'Desfixar conversa'
            : 'Fixar conversa',
        onTap: () => _togglePin(),
        trailing: Switch(
          value: _details?.isPinned ?? false,
          onChanged: (_) => _togglePin(),
          activeThumbColor: theme.colorScheme.primary,
        ),
      ),
    ];
    return ConversationSettingsList(items: items);
  }

  /// Builds tab bar
  TabBar _buildTabBar(ThemeData theme) {
    return TabBar(
      controller: _tabController,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
      indicatorColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      tabs: const [
        Tab(text: 'Multimédia'),
        Tab(text: 'Ficheiros'),
        Tab(text: 'Links'),
      ],
    );
  }

  /// Builds tab content
  Widget _buildTabContent(ThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        ConversationMediaGrid(
          key: const ValueKey('media'),
          conversationId: widget.conversation.id,
          userId: widget.myId,
          type: 'media',
        ),
        ConversationMediaGrid(
          key: const ValueKey('file'),
          conversationId: widget.conversation.id,
          userId: widget.myId,
          type: 'file',
        ),
        ConversationMediaGrid(
          key: const ValueKey('link'),
          conversationId: widget.conversation.id,
          userId: widget.myId,
          type: 'link',
        ),
      ],
    );
  }

  /// Builds danger zone
  Widget _buildDangerZone(ThemeData theme) {
    final isGroup = widget.conversation.isGroup;
    final isCreator = _details?.isCreator ?? false;

    final String label;
    final IconData icon;
    if (isGroup && isCreator) {
      label = 'Eliminar grupo';
      icon = Icons.delete_forever_rounded;
    } else if (isGroup) {
      label = 'Sair do grupo';
      icon = Icons.exit_to_app_rounded;
    } else {
      label = 'Arquivar conversa';
      icon = Icons.archive_rounded;
    }

    return ConversationDangerZone(
      label: label,
      icon: icon,
      onTap: _dangerAction,
    );
  }

  /// Navigates to the selected user profile
  void _openProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => userId == widget.myId
            ? const ProfileScreen()
            : ProfileScreen(userId: userId),
      ),
    );
  }

  /// Opens edit group
  void _openEditGroup() {
    if (_details == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditGroupScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          currentName: _details!.name ?? '',
          currentImage: _details!.image,
        ),
      ),
    ).then((_) => _loadDetails());
  }

  /// Opens members
  void _openMembers() {
    if (_details == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MembersScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          details: _details!,
          isGroup: widget.conversation.isGroup,
        ),
      ),
    ).then((_) => _loadDetails());
  }

  /// Opens notifications
  void _openNotifications() {
    if (_details == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          notification: _details!.notification,
        ),
      ),
    ).then((_) => _loadDetails());
  }

  /// Opens search
  void _openSearch() {
    Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchMessagesScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          members: _details?.members ?? [],
        ),
      ),
    ).then((messageId) {
      if (messageId != null && mounted) {
        Navigator.pop(context, messageId);
      }
    });
  }

  /// Opens theme
  void _openTheme() {
    if (_details == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemeScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          currentTheme: _details!.settings?.theme ?? 0,
          isAdmin: _details!.amAdmin,
        ),
      ),
    ).then((_) => _loadDetails());
  }

  /// Opens ephemeral
  void _openEphemeral() {
    if (_details == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EphemeralMessagesScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          currentDuration: _details!.settings?.ephemeralDuration ?? 0,
          isAdmin: _details!.amAdmin,
        ),
      ),
    ).then((_) => _loadDetails());
  }

  /// Opens admin settings
  void _openAdminSettings() {
    if (_details == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSettingsScreen(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          settings: _details!.settings ?? ConversationSettings(),
        ),
      ),
    ).then((_) => _loadDetails());
  }

  /// Starts call
  void _startCall({required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          conversationName: _displayName,
          avatarUrl: _displayAvatar,
          isVideo: isVideo,
        ),
      ),
    );
  }

  /// Edit description
  void _editDescription() async {
    final controller = TextEditingController(text: _details?.description ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Descrição do grupo'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 256,
          decoration: InputDecoration(
            hintText: 'Escreve uma descrição...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      await ConversationSettingsService.updateSettings(
        widget.conversation.id,
        widget.myId,
        {'description': result},
      );
      await _loadDetails();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descrição atualizada'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  bool get _canEditBio {
    if (_details == null) return false;
    final perm = _details!.settings?.whoCanEditBio ?? 0;
    if (perm == 0) return true;
    return _details!.amAdmin;
  }
}
