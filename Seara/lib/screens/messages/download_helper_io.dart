import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../services/api_client.dart';
import '../../utils/export/export_saver.dart';

/// Downloads and saves the requested file to the user's device.
///
/// Windows: Downloads folder.
/// Mobile: Gallery (for images/videos) or Documents folder (for other file types).
Future<void> downloadFile(String url, String fileName) async {
  final response = await ApiClient.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Falha ao descarregar ficheiro: ${response.statusCode}');
  }

  final bytes = response.bodyBytes;
  final ext = p.extension(fileName).replaceAll('.', '').toLowerCase();

  final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);

  if (isVideo) {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, fileName);
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes);
    await saveExportedVideo(tempPath);
  } else if (isImage) {
    await saveExportedImage(bytes);
  } else {
    if (Platform.isWindows) {
      final downloadsDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final finalPath = p.join(downloadsDir.path, fileName);
      final file = File(finalPath);
      await file.writeAsBytes(bytes);
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      final finalPath = p.join(docsDir.path, fileName);
      final file = File(finalPath);
      await file.writeAsBytes(bytes);
    }
  }
}
