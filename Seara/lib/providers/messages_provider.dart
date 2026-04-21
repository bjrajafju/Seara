import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../services/messages_service.dart';
import '../services/upload_service.dart';

class MessagesProvider extends ChangeNotifier {
  static const List<String> defaultQuickReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
  ];
  final MessagesService _service = MessagesService();

  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMore = false;
  List<Message> _pinnedMessages = [];
  String? _loadError;
  String? _sendError;
  DateTime? _lastReadAt;
  RealtimeChannel? _channel;
  RealtimeChannel? _reactionsChannel;
  final Set<String> _pendingReactionToggles = {};
  ReplyPreview? _replyingTo;
  int? _myUserId;
  List<String> _quickReactions = defaultQuickReactions;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSending => _isSending;
  bool get hasMore => _hasMore;
  String? get error => _loadError;
  String? get sendError => _sendError;
  DateTime? get lastReadAt => _lastReadAt;
  List<Message> get pinnedMessages => _pinnedMessages;
  ReplyPreview? get replyingTo => _replyingTo;
  List<String> get quickReactions => List.unmodifiable(_quickReactions);

  /// Merges incoming messages into local state
  void _upsertMessages(Iterable<Message> incoming) {
    if (incoming.isEmpty) return;
    final byId = <int, Message>{for (final m in _messages) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _messages = merged;
  }

  /// Finds a message by id in local caches
  Message? getMessageById(int messageId) {
    try {
      return _messages.firstWhere((m) => m.id == messageId);
    } catch (_) {
      return null;
    }
  }

  /// Stores the selected message as active reply target
  void startReply(Message target) {
    _replyingTo =
        target.replyTo ??
        ReplyPreview(
          id: target.id,
          userId: target.userId,
          senderUsername: target.senderUsername,
          body: target.body,
          attachmentType: target.attachment != null
              ? target.attachmentType.name
              : null,
          attachmentName: target.attachmentName,
        );
    notifyListeners();
  }

  /// Clears the active reply target
  void cancelReply() {
    if (_replyingTo == null) return;
    _replyingTo = null;
    notifyListeners();
  }

  /// Loads messages for the current conversation
  Future<void> loadMessages(int conversationId, {int? userId}) async {
    _myUserId = userId;
    await _loadQuickReactions(userId);
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final page = await _service.fetchMessages(conversationId, userId: userId);
      _messages = page.messages;
      _hasMore = page.hasMore;
      _lastReadAt = page.lastReadAt;
    } catch (e) {
      _loadError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    fetchPinnedMessages(conversationId);
  }

  /// Loads pinned messages for this conversation
  Future<void> fetchPinnedMessages(int conversationId) async {
    try {
      _pinnedMessages = await _service.getPinnedMessages(conversationId);
      notifyListeners();
    } catch (e) {
      print("Warning: failed to load pinned messages: $e");
    }
  }

  /// Pins or unpins the selected message
  Future<bool> togglePinMessage(int conversationId, Message msg) async {
    try {
      await _service.toggleMessagePin(conversationId, msg.id);
      await fetchPinnedMessages(conversationId);
      return true;
    } catch (e) {
      print("Error toggling pin: $e");
      return false;
    }
  }

  Future<int?> ensureMessageLoaded(
    int conversationId,
    int messageId, {
    int? userId,
  }) async {
    final existingIndex = _messages.indexWhere((m) => m.id == messageId);
    if (existingIndex != -1) return existingIndex;

    try {
      final page = await _service.fetchMessages(
        conversationId,
        around: messageId,
        userId: userId,
      );
      _upsertMessages(page.messages);
      _lastReadAt ??= page.lastReadAt;
      notifyListeners();

      return _messages.indexWhere((m) => m.id == messageId);
    } catch (e) {
      _loadError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<int?> ensureMessageLoadedSafe(
    int conversationId,
    int messageId, {
    int? userId,
    int retries = 3,
  }) async {
    int attempt = 0;
    while (attempt <= retries) {
      final idx = await ensureMessageLoaded(
        conversationId,
        messageId,
        userId: userId,
      );
      if (idx != null && idx >= 0) return idx;
      if (attempt == retries) break;
      await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      attempt += 1;
    }
    return null;
  }

  /// Loads older messages for pagination
  Future<void> loadMore(int conversationId, {int? userId}) async {
    _myUserId ??= userId;
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final oldestId = _messages.first.id;
      final page = await _service.fetchMessages(
        conversationId,
        before: oldestId,
        userId: userId,
      );
      _messages = [...page.messages, ..._messages];
      _hasMore = page.hasMore;
    } catch (e) {
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Loads quick reactions
  Future<void> _loadQuickReactions(int? userId) async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'quick_reactions_$userId';
      final stored = prefs.getStringList(key);
      if (stored != null &&
          stored.length == 5 &&
          stored.every((e) => e.trim().isNotEmpty)) {
        _quickReactions = stored;
      } else {
        _quickReactions = defaultQuickReactions;
      }
    } catch (_) {
      _quickReactions = defaultQuickReactions;
    }
  }

  Future<void> setQuickReactionSlot({
    required int slotIndex,
    required String emoji,
  }) async {
    if (_myUserId == null) return;
    if (slotIndex < 0 || slotIndex >= 5) return;
    if (emoji.trim().isEmpty) return;

    final next = List<String>.from(_quickReactions);
    next[slotIndex] = emoji;
    _quickReactions = next;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'quick_reactions_${_myUserId!}',
        _quickReactions,
      );
    } catch (_) {}
  }

  /// Subscribe to conversation
  void subscribeToConversation(int conversationId) {
    unsubscribe();
    _myUserId = null;
    final client = Supabase.instance.client;
    _channel = client.channel('messages:$conversationId');
    _reactionsChannel = client.channel('reactions:$conversationId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg.isEmpty) return;
            final msgId = newMsg['id'] as int?;
            if (msgId != null && _messages.any((m) => m.id == msgId)) return;
            try {
              final message = Message.fromJson(newMsg);
              _upsertMessages([message]);
              notifyListeners();
            } catch (_) {}
          },
        )
        .subscribe();

    _reactionsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_reactions_with_conversation',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) =>
              _applyRealtimeReaction(payload.newRecord, true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'message_reactions_with_conversation',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) =>
              _applyRealtimeReaction(payload.oldRecord, false),
        )
        .subscribe();
  }

  /// Removes active realtime listeners
  void unsubscribe() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    if (_reactionsChannel != null) {
      Supabase.instance.client.removeChannel(_reactionsChannel!);
      _reactionsChannel = null;
    }
  }

  /// Apply realtime reaction
  void _applyRealtimeReaction(Map<String, dynamic> row, bool added) {
    final messageId = (row['message_id'] as num?)?.toInt();
    final reaction = row['reaction']?.toString();
    final userId = (row['user_id'] as num?)?.toInt();
    if (messageId == null || reaction == null) return;

    final token = '$messageId|$reaction|$userId';
    if (_pendingReactionToggles.remove(token)) return;

    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final old = _messages[idx];
    _messages[idx] = old.copyWith(
      reactions: _toggleReactionInList(
        old.reactions,
        reaction,
        added,
        reactedByMe: _myUserId != null && userId == _myUserId,
      ),
    );
    notifyListeners();
  }

  List<ReactionAggregate> _toggleReactionInList(
    List<ReactionAggregate> current,
    String reaction,
    bool added, {
    required bool reactedByMe,
  }) {
    final map = {for (final r in current) r.reaction: r};
    final existing = map[reaction];
    if (existing == null && added) {
      map[reaction] = ReactionAggregate(
        reaction: reaction,
        count: 1,
        reactedByMe: reactedByMe,
      );
    } else if (existing != null) {
      final nextCount = added ? existing.count + 1 : existing.count - 1;
      if (nextCount <= 0) {
        map.remove(reaction);
      } else {
        map[reaction] = ReactionAggregate(
          reaction: reaction,
          count: nextCount,
          reactedByMe: reactedByMe ? added : existing.reactedByMe,
        );
      }
    }
    return map.values.toList();
  }

  Future<bool> sendMessage({
    required int conversationId,
    required int userId,
    required String body,
    String? attachment,
    String? attachmentType,
    String? attachmentName,
    bool isForwarded = false,
    int? replyToMessageId,
  }) async {
    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final message = await _service.sendMessage(
        conversationId: conversationId,
        userId: userId,
        body: body,
        attachment: attachment,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        isForwarded: isForwarded,
        replyToMessageId: replyToMessageId,
      );
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
      }
      _isSending = false;
      _replyingTo = null;
      notifyListeners();
      return true;
    } catch (e) {
      _sendError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleReaction({
    required int messageId,
    required int userId,
    required String reaction,
  }) async {
    _myUserId = userId;
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final old = _messages[idx];
    final mine = old.reactions.firstWhere(
      (r) => r.reaction == reaction,
      orElse: () =>
          const ReactionAggregate(reaction: '', count: 0, reactedByMe: false),
    );
    final willAdd = !(mine.reaction == reaction && mine.reactedByMe);
    _messages[idx] = old.copyWith(
      reactions: _toggleReactionInList(
        old.reactions,
        reaction,
        willAdd,
        reactedByMe: true,
      ),
    );
    notifyListeners();

    final token = '$messageId|$reaction|$userId';
    _pendingReactionToggles.add(token);
    try {
      await _service.toggleReaction(
        messageId: messageId,
        userId: userId,
        reaction: reaction,
      );
    } catch (_) {
      _pendingReactionToggles.remove(token);
      _messages[idx] = old;
      notifyListeners();
    }
  }

  Future<bool> sendFileMessage({
    required int conversationId,
    required int userId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String body = "",
    int? replyToMessageId,
  }) async {
    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final result = await UploadService.uploadFile(
        bucket: "attachments",
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
      );

      final message = await _service.sendMessage(
        conversationId: conversationId,
        userId: userId,
        body: body,
        attachment: result.url,
        attachmentType: _resolveAttachmentType(
          originalMimeType: mimeType,
          uploadedContentType: result.contentType,
        ),
        attachmentName: result.fileName,
        replyToMessageId: replyToMessageId,
      );

      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
      }
      _isSending = false;
      _replyingTo = null;
      notifyListeners();
      return true;
    } catch (e) {
      _sendError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  String _resolveAttachmentType({
    required String originalMimeType,
    required String uploadedContentType,
  }) {
    final normalizedOriginal = originalMimeType.toLowerCase();
    final normalizedUploaded = uploadedContentType.toLowerCase();

    if (normalizedOriginal.startsWith('audio/')) {
      return normalizedOriginal;
    }

    if (normalizedUploaded.isNotEmpty &&
        normalizedUploaded != 'application/octet-stream') {
      return normalizedUploaded;
    }

    return normalizedOriginal;
  }

  int? get unreadDividerIndex {
    if (_lastReadAt == null) return null;
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].createdAt.isAfter(_lastReadAt!)) {
        return i;
      }
    }
    return null;
  }

  Future<bool> editMessage({
    required int conversationId,
    required int messageId,
    required String newBody,
  }) async {
    _sendError = null;
    notifyListeners();
    try {
      final updatedMessage = await _service.editMessage(
        conversationId: conversationId,
        messageId: messageId,
        newBody: newBody,
      );
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final old = _messages[index];
        _messages[index] = old.copyWith(
          body: updatedMessage.body,
          updatedAt: updatedMessage.updatedAt,
          editedAt: updatedMessage.editedAt,
          replyToMessageId:
              updatedMessage.replyToMessageId ?? old.replyToMessageId,
          replyTo: updatedMessage.replyTo ?? old.replyTo,
          reactions: updatedMessage.reactions.isNotEmpty
              ? updatedMessage.reactions
              : old.reactions,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _sendError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMessage({
    required int conversationId,
    required int messageId,
  }) async {
    _sendError = null;
    notifyListeners();
    try {
      await _service.deleteMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
      return true;
    } catch (e) {
      _sendError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clears provider state for the current conversation
  void clear() {
    unsubscribe();
    _messages = [];
    _loadError = null;
    _sendError = null;
    _isLoading = false;
    _isLoadingMore = false;
    _isSending = false;
    _hasMore = false;
    _lastReadAt = null;
  }
}
