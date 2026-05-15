import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../controllers/editor_controller.dart';

/// Specialized video player for Windows using media_kit directly.
///
/// This bypasses the video_player package on Windows to avoid UnimplementedErrors.
class WindowsVideoWidget extends StatefulWidget {
  final String path;

  const WindowsVideoWidget({super.key, required this.path});

  @override
  State<WindowsVideoWidget> createState() => _WindowsVideoWidgetState();
}

class _WindowsVideoWidgetState extends State<WindowsVideoWidget> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // 1. Configure looping
    await _player.setPlaylistMode(PlaylistMode.loop);

    // 2. Open the media
    // Note: media_kit handles file paths naturally.
    await _player.open(Media(widget.path));

    // 3. Listen for position changes to sync external audio
    // (Mimicking the BaseMediaWidget logic)
    Duration lastPosition = Duration.zero;
    _player.stream.position.listen((position) {
      if (!mounted) return;
      if (position < lastPosition) {
        // Loop detected
        context.read<EditorController>().restartExternalAudio();
      }
      lastPosition = position;
    });

    // 4. Handle mute state
    _player.setVolume(context.read<EditorController>().draft.isMuted ? 0 : 100);
  }

  @override
  void didUpdateWidget(covariant WindowsVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _player.open(Media(widget.path));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch mute state from EditorController
    final isMuted = context.select((EditorController c) => c.draft.isMuted);
    _player.setVolume(isMuted ? 0 : 100);

    return SizedBox.expand(
      child: Video(
        controller: _controller,
        fill: Colors.black,
        fit: BoxFit.cover,
        controls: null, // Disable all native UI/overlays
      ),
    );
  }
}
