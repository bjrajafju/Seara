import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/feed/post_media_source.dart';
import 'post_editor_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  bool _isPicking = false;

  Future<void> _pickFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: kIsWeb,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'mp4',
          'mov',
          'webm',
        ],
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final mimeType = _inferMimeType(file.name);
      final isVideo = mimeType.startsWith('video/');
      final bytes = file.bytes;

      if (kIsWeb && bytes == null) {
        _showError('Não foi possível ler o ficheiro no browser.');
        return;
      }

      final path = kIsWeb ? null : file.path;
      if (!kIsWeb && (path == null || path.isEmpty)) {
        _showError('Não foi possível abrir o ficheiro.');
        return;
      }

      final source = PostMediaSource(
        type: isVideo ? PostMediaType.video : PostMediaType.image,
        mimeType: mimeType,
        fileName: file.name,
        path: path,
        bytes: bytes,
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PostEditorScreen(source: source)),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  String _inferMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return lower.endsWith('.mp4') ? 'video/mp4' : 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Novo post'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _isPicking ? null : _pickFile,
          icon: _isPicking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          label: const Text('Selecionar ficheiro'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: cs.inverseSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }
}
