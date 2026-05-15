import 'dart:typed_data';

/// Creates a temporary Blob URL from [bytes] for browser playback.
/// Returns null on native platforms.
String? createBlobUrl(Uint8List bytes) => null;

/// Revokes a previously created Blob URL to free memory.
/// No-op on native platforms.
void revokeBlobUrl(String? url) {}
