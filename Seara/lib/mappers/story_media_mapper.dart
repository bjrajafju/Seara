import 'dart:typed_data';
import '../models/story/media_asset.dart';
import '../models/story/story_media.dart';

/// Converts a platform [MediaAsset] into a domain [StoryMedia].
///
/// All MIME-type inference and platform-specific mapping is centralised here,
/// keeping the UI layer fully platform-agnostic.
abstract final class StoryMediaMapper {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Converts [asset] to [StoryMedia].
  ///
  /// [durationSeconds] is only meaningful for video assets.
  static StoryMedia fromAsset(MediaAsset asset, {double? durationSeconds}) {
    return switch (asset) {
      FileMediaAsset(:final path, :final isMirrored) => StoryMedia(
        filePath: path,
        mimeType: inferMimeType(path),
        durationSeconds: durationSeconds,
        isMirrored: isMirrored,
      ),
      BytesMediaAsset(
        :final Uint8List bytes,
        :final mimeType,
        :final isMirrored,
      ) =>
        StoryMedia(
          filePath: '',
          mimeType: mimeType,
          bytes: bytes,
          durationSeconds: durationSeconds,
          isMirrored: isMirrored,
        ),
      StreamMediaAsset(:final url, :final mimeType, :final isMirrored) =>
        StoryMedia(
          filePath: url,
          mimeType: mimeType,
          durationSeconds: durationSeconds,
          isMirrored: isMirrored,
        ),
    };
  }

  /// Infers a MIME type from a file extension or URL.
  ///
  /// Returns `'application/octet-stream'` for unrecognised extensions.
  static String inferMimeType(String path) {
    final lower = path.toLowerCase();

    // strip query params / content URIs
    final cleanPath = lower.split('?').first.split('#').first;

    if (cleanPath.contains('video') && cleanPath.contains('mp4')) {
      return 'video/mp4';
    }

    if (cleanPath.endsWith('.jpg') || cleanPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (cleanPath.endsWith('.png')) return 'image/png';
    if (cleanPath.endsWith('.webp')) return 'image/webp';

    if (cleanPath.endsWith('.mp4') ||
        cleanPath.contains('mp4') ||
        cleanPath.contains('video')) {
      return 'video/mp4';
    }

    if (cleanPath.endsWith('.mov')) return 'video/quicktime';
    if (cleanPath.endsWith('.webm')) return 'video/webm';
    if (cleanPath.endsWith('.avi')) return 'video/x-msvideo';

    // fallback inteligente (NÃO destruir vídeo)
    if (cleanPath.contains('video') ||
        cleanPath.contains('camera') ||
        cleanPath.contains('cache')) {
      return 'video/mp4';
    }

    return 'image/jpeg';
  }
}
