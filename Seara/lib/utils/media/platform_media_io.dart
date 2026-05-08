import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Creates a [VideoPlayerController] for a local file path.
///
/// Only called on mobile and Windows — local file paths never exist on web.
VideoPlayerController createLocalFileVideoController(String path) =>
    VideoPlayerController.file(File(path));

/// Builds an [Image] widget from a local file path.
///
/// Only called on mobile and Windows.
Widget buildLocalFileImage(String path, BoxFit fit) => Image.file(
  File(path),
  fit: fit,
  width: double.infinity,
  height: double.infinity,
);
