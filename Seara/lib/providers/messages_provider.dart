import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/messages_service.dart';
import '../services/upload_service.dart';
import 'package:flutter/material.dart';

class MessagesProvider extends ChangeNotifier {
  final MessagesService _service = MessagesService();

  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _loadError;
  String? _sendError;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _loadError;
  String? get sendError => _sendError;

  Future<void> loadMessages(int conversationId) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _messages = await _service.fetchMessages(conversationId);
    } catch (e) {
      _loadError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required int conversationId,
    required int userId,
    required String body,
    String? attachment,
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
      );
      _messages.add(message);
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

  Future<bool> sendImageMessage({
    required int conversationId,
    required int userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final url = await UploadService.uploadImage(
        bucket: "attachments",
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: "image/jpeg",
      );

      final message = await _service.sendMessage(
        conversationId: conversationId,
        userId: userId,
        body: "",
        attachment: url,
      );

      _messages.add(message);
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

  void clear() {
    _messages = [];
    _loadError = null;
    _sendError = null;
    _isLoading = false;
    _isSending = false;
  }
}
