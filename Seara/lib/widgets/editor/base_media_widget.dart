import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/story/story_media.dart';

/// Renders the base media (image or video) for the story editor canvas.
///
/// This widget is a [StatefulWidget] so it can own the [VideoPlayerController]
/// lifecycle — initialised once in [initState], disposed in [dispose],
/// never re-created on rebuild.
///
/// Platform branching is done entirely via [StoryMedia] field inspection
/// (no [Platform.*] or [kIsWeb] checks).
class BaseMediaWidget extends StatefulWidget {
  final StoryMedia media;

  const BaseMediaWidget({super.key, required this.media});

  @override
  State<BaseMediaWidget> createState() => _BaseMediaWidgetState();
}

class _BaseMediaWidgetState extends State<BaseMediaWidget> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final media = widget.media;

    // Prefer file path for mobile/Windows; fall back to network URL for web
    // blob references (StreamMediaAsset stores a blob URL in filePath).
    final ctrl = media.filePath.isNotEmpty
        ? VideoPlayerController.file(File(media.filePath))
        : VideoPlayerController.networkUrl(Uri.parse(media.filePath));

    _videoCtrl = ctrl;

    await ctrl.initialize();
    ctrl.setLooping(true);
    // Always muted in editor — final mute state is stored in StoryDraft.isMuted.
    await ctrl.setVolume(0);
    await ctrl.play();

    if (mounted) setState(() => _videoReady = true);
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isVideo) {
      return _buildVideo();
    }
    return _buildImage();
  }

  Widget _buildVideo() {
    final ctrl = _videoCtrl;
    if (ctrl == null || !_videoReady) {
      return const ColoredBox(color: Colors.black);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: ctrl.value.size.width,
        height: ctrl.value.size.height,
        child: VideoPlayer(ctrl),
      ),
    );
  }

  Widget _buildImage() {
    final media = widget.media;

    // Web photo: BytesMediaAsset stores bytes directly.
    if (media.bytes != null) {
      return Image.memory(
        media.bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Mobile / Windows file path, or web blob/network URL.
    if (media.filePath.isNotEmpty) {
      // Local file on native platforms.
      final isLocalFile =
          !media.filePath.startsWith('http') &&
          !media.filePath.startsWith('blob:');
      if (isLocalFile) {
        return Image.file(
          File(media.filePath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
      // Network / blob URL.
      return Image.network(
        media.filePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Fallback: nothing to show yet.
    return const ColoredBox(color: Colors.black);
  }
}
