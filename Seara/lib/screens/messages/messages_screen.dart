import 'package:flutter/material.dart';
import 'package:seara/models/conversation_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/screens/messages/conversation_screen.dart';
import 'package:seara/screens/messages/new_conversation_screen.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/messages_service.dart';

// Tipos de filtro de conteudo
enum ContentFilter { all, images }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MessagesService _messagesService = MessagesService();

  List<Conversation> _allConversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  bool _isSearching = false;
  int? _myId;

  // Filtros
  ContentFilter _contentFilter = ContentFilter.all;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      int? myId = await AuthService.getUserId();
      if (myId == null) return;
      final data = await _messagesService.fetchConversations(myId);

      setState(() {
        _allConversations = data;
        _filteredConversations = data;
        _isLoading = false;
        _myId = myId;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Chamado sempre que o texto da pesquisa muda
  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredConversations = _applyFilters(_allConversations);
        _isSearching = false;
      });
      return;
    }

    // Pesquisa local imediata por nome e ultima mensagem
    final localResults = _allConversations.where((conv) {
      final otherUser = conv.participants.where((u) => u.id != _myId).toList();

      final displayName = conv.isGroup
          ? (conv.name ?? "").toLowerCase()
          : (otherUser.isNotEmpty
                ? "${otherUser.first.username} ${otherUser.first.name}"
                      .toLowerCase()
                : "");

      final lastMessageBody = conv.messages.isNotEmpty
          ? conv.messages.first.body.toLowerCase()
          : "";

      return displayName.contains(query.toLowerCase()) ||
          lastMessageBody.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredConversations = _applyFilters(localResults);
    });

    // Pesquisa remota por texto de mensagens antigas (3+ caracteres)
    if (query.length >= 3 && _myId != null) {
      _searchRemote(query);
    }
  }

  Future<void> _searchRemote(String query) async {
    setState(() => _isSearching = true);

    try {
      final remoteResults = await _messagesService.searchConversations(
        _myId!,
        query,
      );

      if (!mounted) return;

      // Construir mapa dos resultados remotos por id
      final remoteById = {for (final c in remoteResults) c.id: c};

      // Para cada conversa na lista filtrada atual:
      // se existe versao remota com match, substitui (para mostrar mensagem correta no preview)
      // se nao existe localmente mas existe remotamente, adiciona
      final localIds = _filteredConversations.map((c) => c.id).toSet();

      final merged = [
        ..._filteredConversations.map(
          (c) => remoteById.containsKey(c.id) ? remoteById[c.id]! : c,
        ),
        ...remoteResults.where((c) => !localIds.contains(c.id)),
      ];

      setState(() {
        _filteredConversations = _applyFilters(merged);
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // Aplica filtros de data e tipo sobre uma lista
  List<Conversation> _applyFilters(List<Conversation> list) {
    return list.where((conv) {
      // Filtro por tipo de conteudo
      if (_contentFilter == ContentFilter.images) {
        final lastMsg = conv.messages.isNotEmpty ? conv.messages.first : null;
        if (lastMsg == null || lastMsg.attachment == null) return false;
      }

      // Filtro por data (usa updated_at da conversa)
      if (_filterDateFrom != null) {
        if (conv.updatedAt.isBefore(_filterDateFrom!)) return false;
      }
      if (_filterDateTo != null) {
        // Incluir o dia completo da data de fim
        final endOfDay = DateTime(
          _filterDateTo!.year,
          _filterDateTo!.month,
          _filterDateTo!.day,
          23,
          59,
          59,
        );
        if (conv.updatedAt.isAfter(endOfDay)) return false;
      }

      return true;
    }).toList();
  }

  void _applyAndRefresh() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredConversations = _applyFilters(_allConversations);
      });
    } else {
      _onSearchChanged();
    }
  }

  void _clearFilters() {
    setState(() {
      _contentFilter = ContentFilter.all;
      _filterDateFrom = null;
      _filterDateTo = null;
      _filteredConversations = _applyFilters(_allConversations);
    });
  }

  bool get _hasActiveFilters =>
      _contentFilter != ContentFilter.all ||
      _filterDateFrom != null ||
      _filterDateTo != null;

  // Abre painel de filtros avancados
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterPanel(
        contentFilter: _contentFilter,
        dateFrom: _filterDateFrom,
        dateTo: _filterDateTo,
        onApply: (filter, from, to) {
          setState(() {
            _contentFilter = filter;
            _filterDateFrom = from;
            _filterDateTo = to;
          });
          _applyAndRefresh();
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
                          _searchController.clear();
                          _applyAndRefresh();
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
            "${_filteredConversations.length}",
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

    if (_filteredConversations.isEmpty) {
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
        itemCount: _filteredConversations.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
        itemBuilder: (_, index) =>
            _buildMessageItem(theme, _filteredConversations[index]),
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
    required this.contentFilter,
    required this.dateFrom,
    required this.dateTo,
    required this.onApply,
    required this.onClear,
  });

  final ContentFilter contentFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final void Function(ContentFilter, DateTime?, DateTime?) onApply;
  final VoidCallback onClear;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late ContentFilter _contentFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _contentFilter = widget.contentFilter;
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
        // Garantir que data de fim nao e anterior a data de inicio
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
          const SizedBox(height: 20),

          // Tipo de conteudo
          Text(
            "Tipo de conteudo",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text("Todos"),
                selected: _contentFilter == ContentFilter.all,
                onSelected: (_) =>
                    setState(() => _contentFilter = ContentFilter.all),
              ),
              FilterChip(
                label: const Text("Imagens"),
                selected: _contentFilter == ContentFilter.images,
                onSelected: (_) =>
                    setState(() => _contentFilter = ContentFilter.images),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filtro por data
          Text(
            "Periodo",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _formatPickedDate(_dateFrom),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("ate"),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _formatPickedDate(_dateTo),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botao aplicar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_contentFilter, _dateFrom, _dateTo);
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
