import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';


import '../../models/story/story_draft.dart';
import '../../models/story/story_media.dart';
import '../../models/story/story_type.dart';
import '../upload_service.dart';

/// Handles the full "publish a story" pipeline:
///
/// 1. Upload media bytes to Supabase Storage (bucket: `stories`).
/// 2. Retrieve the public URL for the uploaded file.
/// 3. Insert a new row into the `stories` table.
///
/// This service is stateless — instantiate, call [publish], discard.
class StoryPublishService {
  final _client = Supabase.instance.client;
  static const _bucket = 'stories';

  /// Publishes [draft] to the backend.
  ///
  /// Returns the public URL of the uploaded media on success.
  /// Throws a [StoryPublishException] on any failure.
  Future<String> publish(StoryDraft draft) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StoryPublishException('Utilizador não autenticado.');
    }


    if (draft.media.isEmpty) {
      throw StoryPublishException('Nenhuma media para publicar.');
    }

    final media = draft.media.first;

    // 1. Upload media and get public URL.
    final mediaUrl = await _uploadMedia(media, userId);

    // 2. Determine story metadata.
    final type = draft.type == StoryType.video ? 'video' : 'image';
    final duration = _resolveDuration(draft, media);

    // 3. Insert into the stories table.
    await _insertStory(
      userId: userId,
      mediaUrl: mediaUrl,
      type: type,
      duration: duration,
    );

    return mediaUrl;
  }

  // ── Upload ──────────────────────────────────────────────────────────────────

  Future<String> _uploadMedia(StoryMedia media, String userId) async {
    final ext = _extensionFromMime(media.mimeType);
    final fileName = '${const Uuid().v4()}$ext';

    final bytes = await _resolveBytes(media);

    final result = await UploadService.uploadFile(
      bucket: _bucket,
      fileName: fileName,
      fileBytes: bytes,
      mimeType: media.mimeType,
    );

    return result.url;
  }

  Future<Uint8List> _resolveBytes(StoryMedia media) async {
    // Web: bytes are already in memory or accessible via blob URL.
    if (kIsWeb) {
      if (media.bytes != null) return media.bytes!;
      if (media.filePath.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(media.filePath));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        } catch (e) {
          throw StoryPublishException('Erro ao descarregar a media no browser: $e');
        }
      }
      throw StoryPublishException('Sem dados de media no browser.');
    }

    // Native: read from file path.
    if (media.filePath.isNotEmpty) {
      return await File(media.filePath).readAsBytes();
    }

    // Fallback to in-memory bytes.
    if (media.bytes != null) return media.bytes!;

    throw StoryPublishException('Impossível ler a media.');
  }


  // ── Insert ──────────────────────────────────────────────────────────────────

  Future<void> _insertStory({
    required String userId,
    required String mediaUrl,
    required String type,
    required double duration,
  }) async {
    final now = DateTime.now().toUtc();
    try {
      await _client.from('stories').insert({
        'user_id': userId,
        'media_url': mediaUrl,
        'type': type,
        'duration': duration,
        'created_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
      });
    } on PostgrestException catch (e) {
      debugPrint('StoryPublishService: Database insert failed: ${e.message} (${e.code})');
      debugPrint('StoryPublishService: Details: ${e.details}, Hint: ${e.hint}');
      throw StoryPublishException('Erro ao registar a história na base de dados: ${e.message}');
    } catch (e) {
      debugPrint('StoryPublishService: Unexpected database error: $e');
      throw StoryPublishException('Erro inesperado na base de dados: $e');
    }
  }


  // ── Helpers ─────────────────────────────────────────────────────────────────

  double _resolveDuration(StoryDraft draft, StoryMedia media) {
    if (draft.type != StoryType.video) return 6.0;
    final d = media.durationSeconds;
    if (d != null && d > 0) return d.clamp(0.5, 60.0);
    return 15.0; // safety fallback
  }

  String _extensionFromMime(String mime) {
    switch (mime) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'video/mp4':
        return '.mp4';
      case 'video/quicktime':
        return '.mov';
      default:
        return '.bin';
    }
  }
}

/// Thrown when story publishing fails.
class StoryPublishException implements Exception {
  final String message;
  const StoryPublishException(this.message);

  @override
  String toString() => 'StoryPublishException: $message';
}
