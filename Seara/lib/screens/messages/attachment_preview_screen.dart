import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

enum PreviewType { image, video, audio, file }

class AttachmentPreview {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final PreviewType type;

  AttachmentPreview({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.type,
  });
}

class AttachmentPreviewScreen extends StatefulWidget {
  const AttachmentPreviewScreen({super.key, required this.preview});
  final AttachmentPreview preview;

  @override
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<AttachmentPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();

  // AudioPlayer so e criado se o tipo for audio
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  Uint8List? _croppedBytes;

  @override
  void initState() {
    super.initState();
    if (widget.preview.type == PreviewType.audio) {
      _initAudio();
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    final player = AudioPlayer();

    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });
    player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    try {
      await player.setSourceBytes(widget.preview.bytes);
    } catch (e) {
      // Se o browser nao suportar setSourceBytes, ignora silenciosamente
    }

    if (mounted) setState(() => _audioPlayer = player);
  }

  Future<void> _cropImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Crop nao disponivel no browser.")),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${widget.preview.fileName}',
      );
      await tempFile.writeAsBytes(widget.preview.bytes);

      final cropped = await ImageCropper().cropImage(
        sourcePath: tempFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: "Cortar imagem",
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: "Cortar imagem"),
        ],
      );

      if (cropped == null) return;

      final croppedBytes = await cropped.readAsBytes();
      if (mounted) setState(() => _croppedBytes = croppedBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Erro ao cortar imagem.")));
      }
    }
  }

  Future<void> _toggleAudio() async {
    final player = _audioPlayer;
    if (player == null) return;

    if (_isPlaying) {
      await player.pause();
    } else {
      await player.resume();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _confirm() {
    Navigator.pop(context, {
      'bytes': _croppedBytes ?? widget.preview.bytes,
      'fileName': widget.preview.fileName,
      'mimeType': widget.preview.mimeType,
      'caption': _captionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.inverseSurface,
      appBar: AppBar(
        backgroundColor: cs.inverseSurface,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: cs.onInverseSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.preview.type == PreviewType.image && !kIsWeb)
            IconButton(
              icon: Icon(Icons.crop_rounded, color: cs.onInverseSurface),
              tooltip: "Cortar imagem",
              onPressed: _cropImage,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildPreviewContent(theme)),
          _buildCaptionAndSend(theme),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(ThemeData theme) {
    final cs = theme.colorScheme;
    switch (widget.preview.type) {
      case PreviewType.image:
        return Center(
          child: InteractiveViewer(
            child: Image.memory(
              _croppedBytes ?? widget.preview.bytes,
              fit: BoxFit.contain,
            ),
          ),
        );

      case PreviewType.video:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_rounded,
                color: cs.onInverseSurface,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                widget.preview.fileName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onInverseSurface,
                ),
                textAlign: TextAlign.center,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Preview de video nao disponivel antes do envio.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onInverseSurface.withAlpha(160),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );

      case PreviewType.audio:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audio_file_rounded,
                  color: cs.onInverseSurface,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.preview.fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onInverseSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: cs.onInverseSurface.withAlpha(70),
                    thumbColor: cs.primary,
                  ),
                  child: Slider(
                    value: _audioDuration.inMilliseconds > 0
                        ? (_audioPosition.inMilliseconds /
                                  _audioDuration.inMilliseconds)
                              .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (value) async {
                      final position = Duration(
                        milliseconds: (value * _audioDuration.inMilliseconds)
                            .round(),
                      );
                      await _audioPlayer?.seek(position);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_audioPosition),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onInverseSurface.withAlpha(160),
                      ),
                    ),
                    Text(
                      _formatDuration(_audioDuration),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onInverseSurface.withAlpha(160),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Mostrar loading enquanto o player nao esta pronto
                _audioPlayer == null
                    ? CircularProgressIndicator(color: cs.onInverseSurface)
                    : IconButton(
                        iconSize: 56,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: cs.onInverseSurface,
                        ),
                        onPressed: _toggleAudio,
                      ),
              ],
            ),
          ),
        );

      case PreviewType.file:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                color: cs.onInverseSurface,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                widget.preview.fileName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "${(widget.preview.bytes.length / 1024).toStringAsFixed(1)} KB",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onInverseSurface.withAlpha(160),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCaptionAndSend(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      color: cs.inverseSurface.withAlpha(240),
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _captionController,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onInverseSurface,
              ),
              decoration: InputDecoration(
                hintText: "Adicionar legenda...",
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onInverseSurface.withAlpha(160),
                ),
                filled: true,
                fillColor: cs.surface.withAlpha(40),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _confirm,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(Icons.send_rounded, color: theme.colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }
}
