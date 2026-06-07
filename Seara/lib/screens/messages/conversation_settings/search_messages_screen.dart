import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seara/models/conversation_settings_model.dart';
import 'package:seara/models/message_model.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/services/time_service.dart';
import 'package:seara/utils/message_helpers.dart';

class SearchMessagesScreen extends StatefulWidget {
  const SearchMessagesScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.members,
  });

  final int conversationId;
  final int userId;
  final List<ConversationMember> members;

  @override
  State<SearchMessagesScreen> createState() => _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends State<SearchMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Message> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  String? _typeFilter;
  int? _senderFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final _typeOptions = [
    const _FilterOption(null, 'Todos', Icons.all_inclusive_rounded),
    const _FilterOption('image', 'Imagens', Icons.image_rounded),
    const _FilterOption('video', 'Vídeos', Icons.videocam_rounded),
    const _FilterOption('audio', 'Áudio', Icons.audiotrack_rounded),
    const _FilterOption('file', 'Ficheiros', Icons.insert_drive_file_rounded),
  ];

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _searchController.addListener(_onTextChanged);
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Handles text changed
  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search();
    });
  }

  /// Search
  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty &&
        _typeFilter == null &&
        _senderFilter == null &&
        _dateFrom == null &&
        _dateTo == null) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await ConversationSettingsService.searchMessages(
        widget.conversationId,
        widget.userId,
        query: q.isNotEmpty ? q : null,
        type: _typeFilter,
        senderId: _senderFilter,
        dateFrom: _dateFrom?.toIso8601String(),
        dateTo: _dateTo?.toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  /// Set type filter
  void _setTypeFilter(String? value) {
    setState(() => _typeFilter = value);
    _search();
  }

  /// Set sender filter
  void _setSenderFilter(int? value) {
    setState(() => _senderFilter = value);
    _search();
  }

  /// Picks date
  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? TimeService.now,
      firstDate: DateTime(2020),
      lastDate: TimeService.now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    _search();
  }

  /// Clear dates
  void _clearDates() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _search();
  }

  bool get _hasDateFilter => _dateFrom != null || _dateTo != null;

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
            'Pesquisar mensagens',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodyMedium,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Pesquisar...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
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
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _typeOptions.map((opt) {
                  final selected = _typeFilter == opt.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt.label),
                      avatar: Icon(opt.icon, size: 16),
                      selected: selected,
                      onSelected: (_) {
                        _setTypeFilter(selected ? null : opt.value);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (widget.members.length > 1)
                    Expanded(child: _buildSenderDropdown(theme)),
                  if (widget.members.length > 1) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        _dateFrom != null
                            ? '${_dateFrom!.day}/${_dateFrom!.month}'
                            : 'De',
                        style: theme.textTheme.bodySmall,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: _dateFrom != null
                            ? BorderSide(color: theme.colorScheme.primary)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        _dateTo != null
                            ? '${_dateTo!.day}/${_dateTo!.month}'
                            : 'Até',
                        style: theme.textTheme.bodySmall,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: _dateTo != null
                            ? BorderSide(color: theme.colorScheme.primary)
                            : null,
                      ),
                    ),
                  ),
                  if (_hasDateFilter)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: _clearDates,
                      tooltip: 'Limpar datas',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : !_hasSearched
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface.withAlpha(60),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Escreve ou usa os filtros para pesquisar',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum resultado encontrado.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.dividerColor.withAlpha(40),
                      ),
                      itemBuilder: (context, index) {
                        final msg = _results[index];
                        return _buildMessageResult(theme, msg);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds sender dropdown
  Widget _buildSenderDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: _senderFilter != null
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withAlpha(100),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _senderFilter,
          isExpanded: true,
          isDense: true,
          hint: Text('Utilizador', style: theme.textTheme.bodySmall),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            ...widget.members.map(
              (m) => DropdownMenuItem(
                value: m.id,
                child: Text(m.username, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (val) => _setSenderFilter(val),
        ),
      ),
    );
  }

  /// Builds message result
  Widget _buildMessageResult(ThemeData theme, Message msg) {
    final isImage = msg.attachmentType == AttachmentType.image;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        Navigator.pop(context, msg.id);
      },
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(
          msg.senderAvatar ??
              'https://ui-avatars.com/api/?name=${msg.senderUsername ?? 'U'}',
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              msg.senderUsername ?? 'Utilizador',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${msg.createdAt.day}/${msg.createdAt.month}/${msg.createdAt.year}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
      subtitle: msg.body.isNotEmpty
          ? Text(
              msg.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            )
          : msg.attachment != null
          ? Row(
              children: [
                Icon(
                  isImage ? Icons.image_rounded : Icons.attach_file_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                const SizedBox(width: 4),
                Text(
                  msg.attachmentName ??
                      getAttachmentLabel(msg.attachmentType.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(120),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          : null,
      trailing: isImage && msg.attachment != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                msg.attachment!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            )
          : const Icon(Icons.chevron_right_rounded, size: 18),
    );
  }
}

class _FilterOption {
  final String? value;
  final String label;
  final IconData icon;
  const _FilterOption(this.value, this.label, this.icon);
}
