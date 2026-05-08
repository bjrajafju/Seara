import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Web stub: on web, all video comes from blob/network URLs, never local files.
///
/// If this is somehow called with a path on web, fall back to networkUrl —
/// it will fail gracefully rather than crash with a dart:io error.
VideoPlayerController createLocalFileVideoController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));

/// Web stub: on web, blob/http URLs are handled via [Image.network] directly
/// in [BaseMediaWidget]. This stub is a safety fallback.
Widget buildLocalFileImage(String path, BoxFit fit) => Image.network(
  path,
  fit: fit,
  width: double.infinity,
  height: double.infinity,
);
