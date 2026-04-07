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
import 'package:seara/screens/messages/image_lightbox_screen.dart';
import 'package:seara/screens/messages/video_lightbox_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seara/services/link_preview_service.dart';
import 'package:seara/models/link_preview_model.dart';
import 'package:seara/screens/messages/widgets/link_preview_card.dart';

class ConversationDetailsScreen extends StatefulWidget {
  const ConversationDetailsScreen({
    super.key,
    required this.conversation,
    required this.myId,
  });

  final Conversation conversation;
  final int myId;

  @override
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  // ── FIX #8: Creator sees "Delete group", others see "Leave" ────
  Future<void> _dangerAction() async {
    final isGroup = widget.conversation.isGroup;
    final isCreator = _details?.isCreator ?? false;

    String title;
    String content;
    String actionLabel;

    if (isGroup && isCreator) {
      title = 'Eliminar grupo';
      content =
          'Tens a certeza que queres eliminar este grupo? Todos os membros serão removidos e as mensagens perdidas.';
      actionLabel = 'Eliminar';
    } else if (isGroup) {
      title = 'Sair do grupo';
      content =
          'Tens a certeza que queres sair deste grupo? Não poderás voltar a entrar sem ser adicionado.';
      actionLabel = 'Sair';
    } else {
      title = 'Arquivar conversa';
      content =
          'A conversa será arquivada. Se enviares uma nova mensagem a este utilizador, será restaurada.';
      actionLabel = 'Arquivar';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
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
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ConversationSettingsService.leaveConversation(
        widget.conversation.id,
        widget.myId,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  @override
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
              delegate: _StickyTabBarDelegate(
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

  // ── Sliver AppBar with header ──────────────────────────────────
  Widget _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      pinned: true,
      expandedHeight: 260,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      // FIX #3: For 1:1, add profile icon in AppBar
      actions: [
        if (!widget.conversation.isGroup && _otherUserId != null)
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Ver perfil',
            onPressed: () => _openProfile(_otherUserId!),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: Column(
              children: [
                // Avatar
                GestureDetector(
                  onTap:
                      widget.conversation.isGroup &&
                          (_details?.amAdmin ?? false)
                      ? _openEditGroup
                      : !widget.conversation.isGroup && _otherUserId != null
                      ? () => _openProfile(_otherUserId!)
                      : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(_displayAvatar),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                      if (widget.conversation.isGroup &&
                          (_details?.amAdmin ?? false))
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  _displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtitle
                if (widget.conversation.isGroup)
                  Text(
                    '${_details?.members.length ?? widget.conversation.participants.length} membros',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                // Task 12: Group description
                if (widget.conversation.isGroup &&
                    _details?.description != null &&
                    _details!.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: _canEditBio ? _editDescription : null,
                      child: Text(
                        _details!.description!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(180),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (widget.conversation.isGroup &&
                    (_details?.description == null ||
                        _details!.description!.isEmpty) &&
                    _canEditBio)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: _editDescription,
                      child: Text(
                        'Adicionar descrição...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withAlpha(150),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                if (!widget.conversation.isGroup)
                  Text(
                    '@${widget.conversation.participants.where((u) => u.id != widget.myId).firstOrNull?.username ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Quick action buttons ───────────────────────────────────────
  // FIX #7: Removed duplicate notification — only Search + Call + Video
  Widget _buildActionButtons(ThemeData theme) {
    final actions = [
      _QuickAction(
        icon: Icons.search_rounded,
        label: 'Pesquisar',
        onTap: () => _openSearch(),
      ),
      _QuickAction(
        icon: Icons.call_rounded,
        label: 'Voz',
        onTap: () => _startCall(isVideo: false),
      ),
      _QuickAction(
        icon: Icons.videocam_rounded,
        label: 'Vídeo',
        onTap: () => _startCall(isVideo: true),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) {
          return GestureDetector(
            onTap: action.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    action.icon,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Settings sections ──────────────────────────────────────────
  // FIX #3: Hide "Members" for 1:1, show "Ver perfil" that opens profile
  Widget _buildSettingsSections(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Members (group) or View profile (1:1)
        if (widget.conversation.isGroup)
          _buildSettingRow(
            theme,
            icon: Icons.group_outlined,
            title: 'Membros',
            subtitle: '${_details?.members.length ?? 0} membros',
            onTap: () => _openMembers(),
          ),
        if (!widget.conversation.isGroup && _otherUserId != null)
          _buildSettingRow(
            theme,
            icon: Icons.person_outlined,
            title: 'Ver perfil',
            onTap: () => _openProfile(_otherUserId!),
          ),
        // Notifications
        _buildSettingRow(
          theme,
          icon: Icons.notifications_outlined,
          title: 'Notificações',
          subtitle: _details?.notification.muteLabel ?? 'Ativadas',
          onTap: () => _openNotifications(),
        ),
        // Theme
        _buildSettingRow(
          theme,
          icon: Icons.palette_outlined,
          title: 'Tema da conversa',
          subtitle: _details?.settings?.themeLabel ?? 'Padrão',
          onTap: () => _openTheme(),
        ),
        // Ephemeral messages
        _buildSettingRow(
          theme,
          icon: Icons.timer_outlined,
          title: 'Mensagens temporárias',
          subtitle: _details?.settings?.ephemeralLabel ?? 'Desativado',
          onTap: () => _openEphemeral(),
        ),
        // Admin settings (only for admins in groups)
        if (widget.conversation.isGroup && (_details?.amAdmin ?? false))
          _buildSettingRow(
            theme,
            icon: Icons.admin_panel_settings_outlined,
            title: 'Administração',
            subtitle: 'Permissões e cargos',
            onTap: () => _openAdminSettings(),
          ),
        // Pin toggle
        _buildSettingRow(
          theme,
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
      ],
    );
  }

  Widget _buildSettingRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
          ],
        ),
      ),
    );
  }

  // ── Shared media tabs ──────────────────────────────────────────
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

  // FIX #9: Media tab — pass video type for multimedia, handle all types
  Widget _buildTabContent(ThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        _MediaGrid(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          type: 'media', // images + videos
        ),
        _MediaGrid(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          type: 'file',
        ),
        _MediaGrid(
          conversationId: widget.conversation.id,
          userId: widget.myId,
          type: 'link',
        ),
      ],
    );
  }

  // ── Danger zone (leave/delete/archive) ─────────────────────────
  // FIX #8: Creator sees "Delete group", others see "Leave"
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _dangerAction,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.error),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation helpers ─────────────────────────────────────────

  // Task 1: Self -> my profile, other -> their profile
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
      // FIX #2: If search returned a message ID, pop back with it
      if (messageId != null && mounted) {
        Navigator.pop(context, messageId);
      }
    });
  }

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

  // Task 12: Edit group description dialog
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

  // Fix #1: Bio edit permission check
  bool get _canEditBio {
    if (_details == null) return false;
    final perm = _details!.settings?.whoCanEditBio ?? 0;
    if (perm == 0) return true; // all can edit
    return _details!.amAdmin; // admins only
  }
}

// ── Quick action data class ──────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

// ── FIX #10: Sticky tab bar delegate ─────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  const _StickyTabBarDelegate({required this.tabBar, required this.color});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || color != oldDelegate.color;
  }
}

// ── Shared media grid widget ─────────────────────────────────────
// FIX #9: Handles 'media' (image+video), 'file', 'link' types properly
class _MediaGrid extends StatefulWidget {
  const _MediaGrid({
    required this.conversationId,
    required this.userId,
    required this.type,
  });

  final int conversationId;
  final int userId;
  final String type;

  @override
  State<_MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<_MediaGrid>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await ConversationSettingsService.getSharedMedia(
        widget.conversationId,
        widget.userId,
        type: widget.type,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 36,
              color: theme.colorScheme.error.withAlpha(150),
            ),
            const SizedBox(height: 8),
            Text(
              'Erro ao carregar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      IconData emptyIcon;
      String emptyText;
      switch (widget.type) {
        case 'media':
          emptyIcon = Icons.photo_library_outlined;
          emptyText = 'Sem multimédia partilhada.';
          break;
        case 'file':
          emptyIcon = Icons.folder_outlined;
          emptyText = 'Sem ficheiros partilhados.';
          break;
        case 'link':
          emptyIcon = Icons.link_off_rounded;
          emptyText = 'Sem links partilhados.';
          break;
        default:
          emptyIcon = Icons.folder_open_rounded;
          emptyText = 'Sem conteúdo.';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emptyIcon,
                size: 48,
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
              const SizedBox(height: 12),
              Text(
                emptyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grid for media (images/videos)
    if (widget.type == 'media') {
      return GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isVideo = (item['attachment_type'] ?? '').toString().startsWith(
            'video',
          );
          final url = item['attachment'] ?? '';
          return GestureDetector(
            onTap: () {
              // Task 11: Open image in fullscreen dialog or video player
              if (isVideo) {
                _openVideoPlayer(context, url);
              } else {
                _openImageViewer(context, url);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: theme.colorScheme.onSurface.withAlpha(80),
                    ),
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    // Task 10: Link list — show URLs from message body with preview
    if (widget.type == 'link') {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final body = item['body'] ?? '';
          final urlMatch = RegExp(r'(https?://[^\s]+)').firstMatch(body);
          final url = urlMatch?.group(0) ?? body;
          return InkWell(
            onTap: () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<LinkPreview?>(
                    future: LinkPreviewService.fetchLinkPreview(url),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return LinkPreviewCard(preview: snapshot.data!);
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          url,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatDate(
                            DateTime.tryParse(item['created_at'] ?? ''),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Task 11: File list — tappable for download
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final name = item['attachment_name'] ?? 'Ficheiro';
        final url = item['attachment'] ?? '';
        return ListTile(
          onTap: () => _confirmDownload(context, url, name),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatDate(DateTime.tryParse(item['created_at'] ?? '')),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          trailing: Icon(
            Icons.download_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Task 11: Open image fullscreen
  void _openImageViewer(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ImageLightboxScreen(imageUrl: url),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // Fix #6: Open video inline via VideoLightboxScreen
  void _openVideoPlayer(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => VideoLightboxScreen(videoUrl: url),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // Fix #7: Download confirmation dialog
  Future<void> _confirmDownload(
    BuildContext context,
    String url,
    String fileName,
  ) async {
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
    if (confirmed == true) {
      final uri = Uri.tryParse(url);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
