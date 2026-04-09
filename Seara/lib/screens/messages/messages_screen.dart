import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/screens/messages/conversation_screen.dart';
import 'package:seara/screens/messages/new_conversation_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/messages_service.dart';

enum ContentFilter { all, images, videos, audio, documents }
enum TypeFilter { all, group, direct }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MessagesService _messagesService = MessagesService();
  Timer? _debounce;

  List<Conversation> _conversations = [];
  bool _isLoading = true;
  bool _isSearching = false;
  int? _myId;

  // Filtros
  ContentFilter _contentFilter = ContentFilter.all;
  TypeFilter _typeFilter = TypeFilter.all;
  bool _filterUnread = false;
  bool _filterPinned = false;
  bool _filterOnlyUsernames = false;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    try {
      int? myId = await AuthService.getUserId();
      if (myId == null) return;
      
      if (mounted) setState(() {
        _isSearching = _searchController.text.isNotEmpty;
        if (_conversations.isEmpty) _isLoading = true;
      });

      final Map<String, String> filters = {};
      final q = _searchController.text.trim();
      
      if (q.isNotEmpty) filters['q'] = q;
      if (_filterOnlyUsernames) filters['only_usernames'] = 'true';
      if (_filterUnread) filters['unread'] = 'true';
      if (_filterPinned) filters['is_pinned'] = 'true';
      if (_typeFilter == TypeFilter.group) filters['type'] = 'group';
      else if (_typeFilter == TypeFilter.direct) filters['type'] = 'direct';

      if (_contentFilter == ContentFilter.images) filters['file_type'] = 'images';
      else if (_contentFilter == ContentFilter.videos) filters['file_type'] = 'videos';
      else if (_contentFilter == ContentFilter.audio) filters['file_type'] = 'audio';
      else if (_contentFilter == ContentFilter.documents) filters['file_type'] = 'documents';

      if (_filterDateFrom != null) filters['date_from'] = _filterDateFrom!.toIso8601String();
      if (_filterDateTo != null) filters['date_to'] = _filterDateTo!.toIso8601String();

      final data = await _messagesService.fetchConversations(myId, filters: filters);

      if (mounted) {
        setState(() {
          _conversations = data;
          _isLoading = false;
          _isSearching = false;
          _myId = myId;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _contentFilter = ContentFilter.all;
      _typeFilter = TypeFilter.all;
      _filterUnread = false;
      _filterPinned = false;
      _filterOnlyUsernames = false;
      _filterDateFrom = null;
      _filterDateTo = null;
    });
    _loadConversations();
  }

  bool get _hasActiveFilters =>
      _contentFilter != ContentFilter.all ||
      _typeFilter != TypeFilter.all ||
      _filterUnread ||
      _filterPinned ||
      _filterOnlyUsernames ||
      _filterDateFrom != null ||
      _filterDateTo != null;

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterPanel(
        contentFilter: _contentFilter,
        typeFilter: _typeFilter,
        filterUnread: _filterUnread,
        filterPinned: _filterPinned,
        filterOnlyUsernames: _filterOnlyUsernames,
        dateFrom: _filterDateFrom,
        dateTo: _filterDateTo,
        onApply: (cFilter, tFilter, unread, pinned, onlyUsers, from, to) {
          setState(() {
            _contentFilter = cFilter;
            _typeFilter = tFilter;
            _filterUnread = unread;
            _filterPinned = pinned;
            _filterOnlyUsernames = onlyUsers;
            _filterDateFrom = from;
            _filterDateTo = to;
          });
          _loadConversations();
        },
        onClear: _clearFilters,
      ),
    );
  }

  // Preview da ultima mensagem
  String _buildLastMessagePreview(Message message) {
    if (message.body.isNotEmpty) return message.body;
    if (message.attachment != null) return "Imagem";
    return "Sem mensagens";
  }

  // SEARCH BAR
  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
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
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear(); // Will trigger _onSearchChanged automatically
                        },
                      )
                    : _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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
          ),
          const SizedBox(width: 8),
          // Botao de filtros — fica destacado quando ha filtros ativos
          IconButton(
            onPressed: _showFilterPanel,
            icon: Icon(
              _hasActiveFilters
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color: _hasActiveFilters
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: "Filtros",
          ),
        ],
      ),
    );
  }

  // HEADER de resultados
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
            "${_conversations.length}",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
          if (_hasActiveFilters) ...[
            const Spacer(),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text("Limpar filtros"),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ITEM de conversa
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

    final previewText = lastMessage != null
        ? _buildLastMessagePreview(lastMessage)
        : "Sem mensagens";

    final isImagePreview =
        lastMessage?.body.isEmpty == true && lastMessage?.attachment != null;

    final unreadCount = conversation.unreadCount;
    final isPinned = conversation.isPinned;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: conversation),
          ),
        );
        // Recarregar conversas ao voltar para atualizar previews
        _loadConversations();
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
                  Row(
                    children: [
                      if (isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: theme.colorScheme.primary.withAlpha(150),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unreadCount > 0
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withAlpha(150),
                      fontWeight: unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                      fontStyle: isImagePreview
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastMessage != null)
                  Text(
                    _formatDate(lastMessage.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: unreadCount > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withAlpha(150),
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff == 1) {
      return "Ontem";
    } else if (diff < 7) {
      const days = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sab", "Dom"];
      return days[date.weekday - 1];
    } else {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
  }

  // LISTA de conversas
  Widget _buildConversationsList(ThemeData theme) {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_conversations.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            _searchController.text.isNotEmpty || _hasActiveFilters
                ? "Nenhum resultado encontrado."
                : "Sem conversas ainda.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ),
      );
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

  Widget _buildNewMessageButton(ThemeData theme) {
    return FloatingActionButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewConversationScreen()),
        );
        _loadConversations();
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

  Widget _buildBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(theme),
        _buildResultsHeader(theme),
        const SizedBox(height: 8),
        _buildConversationsList(theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
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

// Painel de filtros avancados
class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    super.key,
    required this.contentFilter,
    required this.typeFilter,
    required this.filterUnread,
    required this.filterPinned,
    required this.filterOnlyUsernames,
    required this.dateFrom,
    required this.dateTo,
    required this.onApply,
    required this.onClear,
  });

  final ContentFilter contentFilter;
  final TypeFilter typeFilter;
  final bool filterUnread;
  final bool filterPinned;
  final bool filterOnlyUsernames;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final void Function(
    ContentFilter,
    TypeFilter,
    bool,
    bool,
    bool,
    DateTime?,
    DateTime?,
  ) onApply;
  final VoidCallback onClear;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late ContentFilter _contentFilter;
  late TypeFilter _typeFilter;
  late bool _filterUnread;
  late bool _filterPinned;
  late bool _filterOnlyUsernames;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _contentFilter = widget.contentFilter;
    _typeFilter = widget.typeFilter;
    _filterUnread = widget.filterUnread;
    _filterPinned = widget.filterPinned;
    _filterOnlyUsernames = widget.filterOnlyUsernames;
    _dateFrom = widget.dateFrom;
    _dateTo = widget.dateTo;
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
          _dateTo = _dateFrom;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(_dateTo!)) {
          _dateFrom = _dateTo;
        }
      }
    });
  }

  String _formatPickedDate(DateTime? date) {
    if (date == null) return "Qualquer data";
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Filtros",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  widget.onClear();
                  Navigator.pop(context);
                },
                child: const Text("Limpar"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type
                  Text(
                    "Tipo de conversa",
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text("Todas"),
                        selected: _typeFilter == TypeFilter.all,
                        onSelected: (_) => setState(() => _typeFilter = TypeFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text("Individuais"),
                        selected: _typeFilter == TypeFilter.direct,
                        onSelected: (_) => setState(() => _typeFilter = TypeFilter.direct),
                      ),
                      ChoiceChip(
                        label: const Text("Grupos"),
                        selected: _typeFilter == TypeFilter.group,
                        onSelected: (_) => setState(() => _typeFilter = TypeFilter.group),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status
                  Text(
                    "Status",
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text("Não Lidas"),
                        selected: _filterUnread,
                        onSelected: (val) => setState(() => _filterUnread = val),
                      ),
                      FilterChip(
                        label: const Text("Fixadas"),
                        selected: _filterPinned,
                        onSelected: (val) => setState(() => _filterPinned = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content Type
                  Text(
                    "Mídia/Arquivos",
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text("Tudo"),
                        selected: _contentFilter == ContentFilter.all,
                        onSelected: (_) => setState(() => _contentFilter = ContentFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text("Imagens"),
                        selected: _contentFilter == ContentFilter.images,
                        onSelected: (_) => setState(() => _contentFilter = ContentFilter.images),
                      ),
                      ChoiceChip(
                        label: const Text("Vídeos"),
                        selected: _contentFilter == ContentFilter.videos,
                        onSelected: (_) => setState(() => _contentFilter = ContentFilter.videos),
                      ),
                      ChoiceChip(
                        label: const Text("Áudio"),
                        selected: _contentFilter == ContentFilter.audio,
                        onSelected: (_) => setState(() => _contentFilter = ContentFilter.audio),
                      ),
                      ChoiceChip(
                        label: const Text("Documentos"),
                        selected: _contentFilter == ContentFilter.documents,
                        onSelected: (_) => setState(() => _contentFilter = ContentFilter.documents),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Usernames search toggle
                  SwitchListTile(
                    title: const Text("Pesquisar apenas identificadores/nomes"),
                    subtitle: const Text("Ignorar o conteúdo das mensagens ao buscar."),
                    value: _filterOnlyUsernames,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _filterOnlyUsernames = val),
                  ),
                  const SizedBox(height: 8),

                  // Dates
                  Text(
                    "Período",
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(_formatPickedDate(_dateFrom), style: theme.textTheme.bodySmall),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("até"),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(_formatPickedDate(_dateTo), style: theme.textTheme.bodySmall),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(
                  _contentFilter,
                  _typeFilter,
                  _filterUnread,
                  _filterPinned,
                  _filterOnlyUsernames,
                  _dateFrom,
                  _dateTo,
                );
                Navigator.pop(context);
              },
              child: const Text("Aplicar filtros"),
            ),
          ),
        ],
      ),
    );
  }
}
