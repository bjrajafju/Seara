import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import 'package:seara/services/global_audio_manager.dart';

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
  /// Creates the state object for this screen
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<AttachmentPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();

  final GlobalAudioManager _audio = GlobalAudioManager.instance;

  bool _audioPrepared = false;
  String? _windowsTempAudioPath;

  Uint8List? _croppedBytes;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    if (widget.preview.type == PreviewType.audio) {
      unawaited(_prepareAudio());
    }
  }

  /// Safe delete windows temp audio
  void _safeDeleteWindowsTempAudio() {
    final p = _windowsTempAudioPath;
    if (p == null) return;
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    _captionController.dispose();
    if (widget.preview.type == PreviewType.audio) {
      if (_audio.currentMessageId == kAttachmentPreviewMessageId) {
        unawaited(_audio.stop());
      }
      _safeDeleteWindowsTempAudio();
    }
    super.dispose();
  }

  /// Prepare audio
  Future<void> _prepareAudio() async {
    try {
      if (!kIsWeb && Platform.isWindows) {
        final tempDir = await getTemporaryDirectory();
        final safeFileName = p.basename(widget.preview.fileName);
        final tempPath = p.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_$safeFileName',
        );
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(widget.preview.bytes, flush: true);
        _windowsTempAudioPath = tempPath;
        await _audio.prepareFromFile(kAttachmentPreviewMessageId, tempPath);
      } else {
        await _audio.prepareFromBytes(
          kAttachmentPreviewMessageId,
          widget.preview.bytes,
          mimeType: widget.preview.mimeType,
        );
      }
      if (mounted) setState(() => _audioPrepared = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao carregar audio para preview.")),
        );
      }
    }
  }

  /// Toggles preview audio
  Future<void> _togglePreviewAudio() async {
    if (!_audioPrepared) return;

    if (_audio.isPlaying(kAttachmentPreviewMessageId)) {
      await _audio.pause();
      return;
    }
    if (_audio.currentMessageId == kAttachmentPreviewMessageId) {
      await _audio.resume();
      return;
    }

    if (!kIsWeb && Platform.isWindows && _windowsTempAudioPath != null) {
      await _audio.prepareFromFile(
        kAttachmentPreviewMessageId,
        _windowsTempAudioPath!,
      );
    } else {
      await _audio.prepareFromBytes(
        kAttachmentPreviewMessageId,
        widget.preview.bytes,
        mimeType: widget.preview.mimeType,
      );
    }
    await _audio.resume();
  }

  /// Formats duration
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  /// Confirm
  void _confirm() {
    Navigator.pop(context, {
      'bytes': _croppedBytes ?? widget.preview.bytes,
      'fileName': widget.preview.fileName,
      'mimeType': widget.preview.mimeType,
      'caption': _captionController.text.trim(),
    });
  }

  @override
  /// Builds the widget tree for this view
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

  /// Crop image
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

  /// Builds preview content
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: !_audioPrepared
                ? CircularProgressIndicator(color: cs.onInverseSurface)
                : StreamBuilder<String?>(
                    stream: _audio.activeMessageIdStream,
                    initialData: _audio.lastActiveMessageId,
                    builder: (context, activeSnap) {
                      final isPreview =
                          activeSnap.data == kAttachmentPreviewMessageId;

                      return StreamBuilder<PlayerState>(
                        stream: _audio.playerStateStream,
                        initialData: _audio.lastPlayerState,
                        builder: (context, stateSnap) {
                          final st = stateSnap.data!;
                          final playing =
                              isPreview &&
                              st.playing &&
                              st.processingState != ProcessingState.completed;

                          return StreamBuilder<Duration>(
                            stream: _audio.positionStream,
                            initialData: isPreview
                                ? _audio.lastPosition
                                : Duration.zero,
                            builder: (context, posSnap) {
                              final pos = isPreview
                                  ? (posSnap.data ?? Duration.zero)
                                  : Duration.zero;

                              return StreamBuilder<Duration?>(
                                stream: _audio.durationStream,
                                initialData: isPreview
                                    ? _audio.lastDuration
                                    : null,
                                builder: (context, durSnap) {
                                  final dur = isPreview
                                      ? (durSnap.data ?? Duration.zero)
                                      : Duration.zero;

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        iconSize: 56,
                                        icon: Icon(
                                          playing
                                              ? Icons
                                                    .pause_circle_filled_rounded
                                              : Icons
                                                    .play_circle_filled_rounded,
                                          color: cs.onInverseSurface,
                                        ),
                                        onPressed: _togglePreviewAudio,
                                      ),
                                      const SizedBox(height: 20),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: cs.primary,
                                          inactiveTrackColor: cs
                                              .onInverseSurface
                                              .withAlpha(70),
                                          thumbColor: cs.primary,
                                        ),
                                        child: Slider(
                                          value: dur.inMilliseconds > 0
                                              ? (pos.inMilliseconds /
                                                        dur.inMilliseconds)
                                                    .clamp(0.0, 1.0)
                                              : 0.0,
                                          onChanged: (value) async {
                                            if (!isPreview ||
                                                dur == Duration.zero) {
                                              return;
                                            }
                                            final position = Duration(
                                              milliseconds:
                                                  (value * dur.inMilliseconds)
                                                      .round(),
                                            );
                                            await _audio.seek(position);
                                          },
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(pos),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: cs.onInverseSurface
                                                      .withAlpha(160),
                                                ),
                                          ),
                                          Text(
                                            _formatDuration(dur),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: cs.onInverseSurface
                                                      .withAlpha(160),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
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

  /// Builds caption and send
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
