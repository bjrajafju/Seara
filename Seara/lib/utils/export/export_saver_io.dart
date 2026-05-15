import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Generates a human-friendly filename like seara_2026-05-14_14-32-10.ext
String _generateFileName(String extension) {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  final second = now.second.toString().padLeft(2, '0');

  return 'seara_${year}-$month-$day\_$hour-$minute-$second.$extension';
}

/// Saves [bytes] as a PNG to the appropriate location.
///
/// Windows: User's Downloads folder.
/// Mobile: System Gallery.
Future<String> saveExportedImage(Uint8List bytes) async {
  final fileName = _generateFileName('png');

  if (Platform.isWindows) {
    final downloadsDir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final finalPath = p.join(downloadsDir.path, fileName);
    final file = File(finalPath);
    await file.writeAsBytes(bytes);
    return finalPath;
  } else {
    // Mobile: Save to temp first, then to gallery via Gal
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, fileName);
    final file = File(tempPath);
    await file.writeAsBytes(bytes);

    await Gal.putImage(tempPath);

    // We can return the gallery indicator or keep the temp path for preview,
    // but the user wants the final location feedback.
    return 'Gallery';
  }
}

/// Saves a video from [tempPath] to the appropriate location.
///
/// Windows: User's Downloads folder (Move).
/// Mobile: System Gallery.
Future<String> saveExportedVideo(String tempPath) async {
  final fileName = _generateFileName('mp4');

  if (Platform.isWindows) {
    final downloadsDir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final finalPath = p.join(downloadsDir.path, fileName);

    // Move from temp to Downloads
    await File(tempPath).copy(finalPath);
    try {
      await File(tempPath).delete();
    } catch (_) {}

    return finalPath;
  } else {
    // Mobile: Save to gallery
    await Gal.putVideo(tempPath);

    // Cleanup temp
    try {
      await File(tempPath).delete();
    } catch (_) {}

    return 'Gallery';
  }
}
