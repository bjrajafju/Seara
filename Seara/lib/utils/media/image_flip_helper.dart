import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility to manipulate image bytes.
abstract final class ImageFlipHelper {
  /// Flips the given [imageBytes] horizontally and returns the flipped bytes.
  ///
  /// Supports JPG and PNG. WebP falls back to JPG encoding.
  static Uint8List flipHorizontal(Uint8List imageBytes, String mimeType) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return imageBytes;

      final flipped = img.flipHorizontal(decoded);

      if (mimeType == 'image/png') {
        return Uint8List.fromList(img.encodePng(flipped));
      }
      return Uint8List.fromList(img.encodeJpg(flipped, quality: 90));
    } catch (e) {
      // In case of any processing exception, safely fallback to the original bytes
      return imageBytes;
    }
  }
}
