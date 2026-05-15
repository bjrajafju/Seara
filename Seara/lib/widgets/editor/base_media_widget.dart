import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/editor_controller.dart';
import '../../models/story/story_media.dart';
import '../../utils/media/platform_media_factory.dart';
import 'windows_video_widget.dart';

/// Renders the base media (image or video) for the story editor canvas.
class BaseMediaWidget extends StatefulWidget {
  final StoryMedia media;

  const BaseMediaWidget({super.key, required this.media});

  @override
  State<BaseMediaWidget> createState() => _BaseMediaWidgetState();
}

class _BaseMediaWidgetState extends State<BaseMediaWidget> {
  VideoPlayerController? _videoCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo && !kIsWeb && !Platform.isWindows) {
      _initVideo();
    }
  }

  Duration _lastPosition = Duration.zero;

  Future<void> _initVideo() async {
    final media = widget.media;
    final path = media.filePath;

    final ctrl = _isRemoteUrl(path)
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : createLocalFileVideoController(path);

    _videoCtrl = ctrl;

    await ctrl.initialize();
    await ctrl.setLooping(true);

    ctrl.addListener(() {
      if (!mounted) return;
      final current = ctrl.value.position;
      if (current < _lastPosition) {
        context.read<EditorController>().restartExternalAudio();
      }
      _lastPosition = current;
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    Widget content;

    if (media.isVideo) {
      if (!kIsWeb && Platform.isWindows) {
        content = WindowsVideoWidget(path: media.filePath);
      } else {
        final ctrl = _videoCtrl;
        if (ctrl == null || !ctrl.value.isInitialized) {
          content = const Center(child: CircularProgressIndicator());
        } else {
          // Watch mute state from EditorController
          final isMuted =
              context.select((EditorController c) => c.draft.isMuted);
          ctrl.setVolume(isMuted ? 0 : 1.0);

          content = SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            ),
          );
        }
      }
    } else {
      // Image logic
      if (media.bytes != null) {
        content = Image.memory(media.bytes!, fit: BoxFit.cover);
      } else {
        content = SizedBox.expand(
          child: _isRemoteUrl(media.filePath)
              ? Image.network(media.filePath, fit: BoxFit.cover)
              : buildLocalFileImage(media.filePath, BoxFit.cover),
        );
      }
    }

    if (media.isMirrored) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: content,
      );
    }

    return content;
  }

  static bool _isRemoteUrl(String path) =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:');
}
