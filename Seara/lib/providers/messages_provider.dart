import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../services/messages_service.dart';
import '../services/upload_service.dart';

class MessagesProvider extends ChangeNotifier {
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

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSending => _isSending;
  bool get hasMore => _hasMore;
  String? get error => _loadError;
  String? get sendError => _sendError;
  DateTime? get lastReadAt => _lastReadAt;
  List<Message> get pinnedMessages => _pinnedMessages;

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

  /// Load initial page of messages.
  Future<void> loadMessages(int conversationId, {int? userId}) async {
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

    // Non-blocking fetch of pinned messages
    fetchPinnedMessages(conversationId);
  }

  Future<void> fetchPinnedMessages(int conversationId) async {
    try {
      _pinnedMessages = await _service.getPinnedMessages(conversationId);
      notifyListeners();
    } catch (e) {
      print("Warning: failed to load pinned messages: $e");
    }
  }

  Future<bool> togglePinMessage(int conversationId, Message msg) async {
    try {
      await _service.toggleMessagePin(conversationId, msg.id);
      // Source of truth is backend; refresh pinned list to avoid stale/duplicate state.
      await fetchPinnedMessages(conversationId);
      return true;
    } catch (e) {
      print("Error toggling pin: $e");
      return false;
    }
  }

  /// Ensures a message is present in memory (fetching if needed) and returns its index.
  ///
  /// This **merges** results into the existing list (does not replace the page),
  /// improving UX for "jump to message" (pinned/search navigation).
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
      // Keep existing pagination flags (around endpoint is not meant to define hasMore for timeline browsing)
      _lastReadAt ??= page.lastReadAt;
      notifyListeners();

      return _messages.indexWhere((m) => m.id == messageId);
    } catch (e) {
      // Don't clobber the whole screen with a load error for a jump action; just surface via error state.
      _loadError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Load older messages (scroll up).
  Future<void> loadMore(int conversationId, {int? userId}) async {
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
      // Silently fail on load more
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Task 4: Real-time subscription via Supabase Realtime
  void subscribeToConversation(int conversationId) {
    unsubscribe();
    final client = Supabase.instance.client;
    _channel = client.channel('messages:$conversationId');
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
            // Don't duplicate messages we already sent locally
            final msgId = newMsg['id'] as int?;
            if (msgId != null && _messages.any((m) => m.id == msgId)) return;
            try {
              final message = Message.fromJson(newMsg);
              _messages.add(message);
              notifyListeners();
            } catch (_) {
              // Ignore parse errors from partial data
            }
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
  }

  Future<bool> sendMessage({
    required int conversationId,
    required int userId,
    required String body,
    String? attachment,
    String? attachmentType,
    String? attachmentName,
    bool isForwarded = false,
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
      );
      // Fix #2: Dedup — only add if not already present from realtime
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
      }
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _sendError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendFileMessage({
    required int conversationId,
    required int userId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String body = "",
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
        attachmentType: result.contentType,
        attachmentName: result.fileName,
      );

      // Fix #2: Dedup — only add if not already present from realtime
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
      }
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _sendError = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // Find the index of the "unread divider" based on lastReadAt.
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
        _messages[index] = updatedMessage;
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
