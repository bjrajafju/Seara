import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/story/story_media.dart';
import '../../utils/media/platform_media_factory.dart';

/// Renders the base media (image or video) for the story editor canvas.
///
/// This widget is a [StatefulWidget] so it can own the [VideoPlayerController]
/// lifecycle — initialised once in [initState], disposed in [dispose],
/// never re-created on rebuild.
///
/// Platform routing is done entirely via [StoryMedia] field inspection and
/// the [platform_media_factory] conditional-import utility — no [Platform.*],
/// no [kIsWeb], no direct [dart:io] imports in this file.
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
    if (widget.media.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final media = widget.media;
    final path = media.filePath;

    // Route to the correct controller type:
    // - blob: or http(s): URLs → networkUrl (web video, or HLS on native)
    // - everything else         → local file via platform factory (dart:io on native only)
    final ctrl = _isRemoteUrl(path)
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : createLocalFileVideoController(path);

    _videoCtrl = ctrl;

    await ctrl.initialize();
    await ctrl.setLooping(true);
    // Always muted in editor — final mute state is stored in StoryDraft.isMuted.
    await ctrl.setVolume(0);
    await ctrl.play();

    // Guard against the widget being disposed during async initialization.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isVideo) return _buildVideo();
    return _buildImage();
  }

  Widget _buildVideo() {
    final ctrl = _videoCtrl;
    // Use the controller's own isInitialized flag — authoritative lifecycle guard.
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: ctrl.value.size.width,
        height: ctrl.value.size.height,
        child: Transform.scale(
          scaleX: -1, // Horizontal mirror
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final media = widget.media;

    // Web photo: BytesMediaAsset stores bytes — no platform code required.
    if (media.bytes != null) {
      return Image.memory(
        media.bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (media.filePath.isNotEmpty) {
      // Remote / blob URL — Image.network works on all platforms.
      if (_isRemoteUrl(media.filePath)) {
        return Image.network(
          media.filePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
      // Local file — delegate to platform factory (dart:io on native only).
      return buildLocalFileImage(media.filePath, BoxFit.cover);
    }

    return const ColoredBox(color: Colors.black);
  }

  /// Returns true for URLs that must be fetched over the network
  /// (http, https) or blob references (blob:).
  static bool _isRemoteUrl(String path) =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:');
}
