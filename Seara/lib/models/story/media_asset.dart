import 'dart:typed_data';

/// Platform-agnostic representation of a captured media asset.
///
/// Use [FileMediaAsset] on mobile and Windows where a persistent local path
/// is available. Use [BytesMediaAsset] for web photos (small, read into memory).
/// Use [StreamMediaAsset] for web video, which is referenced by a temporary
/// blob URL and should not be loaded fully into memory.
sealed class MediaAsset {
  final bool isMirrored;
  const MediaAsset({this.isMirrored = false});
}

/// Mobile / Windows: media is available as a persistent local file path.
class FileMediaAsset extends MediaAsset {
  final String path;
  const FileMediaAsset(this.path, {super.isMirrored});
}

/// Web photos: raw bytes held in memory.
///
/// Only suitable for small media (still images). Do NOT use for video.
class BytesMediaAsset extends MediaAsset {
  final Uint8List bytes;

  /// MIME type, e.g. `'image/jpeg'`.
  final String mimeType;

  const BytesMediaAsset({
    required this.bytes,
    required this.mimeType,
    super.isMirrored,
  });
}

/// Web video: temporary blob URL or stream reference.
///
/// The URL is only valid for the lifetime of the current browser session.
/// Intended for immediate playback or upload — not for local persistence.
class StreamMediaAsset extends MediaAsset {
  /// Blob URL, e.g. `blob:https://localhost:5000/...`
  final String url;

  /// MIME type, e.g. `'video/webm'`.
  final String mimeType;

  const StreamMediaAsset({
    required this.url,
    required this.mimeType,
    super.isMirrored,
  });
}
