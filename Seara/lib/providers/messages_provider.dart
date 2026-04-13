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
  }

  /// Load messages around a specific message (for jump-to-message feature).
  /// Returns the index of the target message in the loaded messages.
  Future<int?> loadMessagesAround(
    int conversationId,
    int messageId, {
    int? userId,
  }) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final page = await _service.fetchMessages(
        conversationId,
        around: messageId,
        userId: userId,
      );
      _messages = page.messages;
      _hasMore = page.hasMore;
      _lastReadAt = page.lastReadAt;
      return page.targetIndex;
    } catch (e) {
      _loadError = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
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
