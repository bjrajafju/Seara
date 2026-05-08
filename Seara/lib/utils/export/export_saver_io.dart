import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Saves [bytes] as a PNG to the system temporary directory.
///
/// Returns the absolute file path on success.
/// Used on mobile and Windows — never imported by web builds.
Future<String> saveExportedImage(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}.png';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
