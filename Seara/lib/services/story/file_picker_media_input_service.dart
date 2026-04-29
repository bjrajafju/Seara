import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/story/media_asset.dart';
import 'media_input_service.dart';

/// Web / desktop fallback implementation of [MediaInputService].
///
/// Instead of live camera recording, it opens a file picker:
/// - capturePhoto → image picker
/// - startVideoRecording → video picker (selection happens immediately)
/// - stopVideoRecording → returns the previously selected video path
///
/// hasCameraPreview is false, so the UI shows a static background instead.
class FilePickerMediaInputService implements MediaInputService {
  /// Holds the video path selected during [startVideoRecording].
  String? _pendingVideoPath;

  @override
  bool get hasCameraPreview => false;

  @override
  CameraPreviewData? getPreview(BuildContext context) {
    // No live camera on this platform — UI should render its own fallback.
    return null;
  }

  @override
  Future<bool> initialize() async {
    // No hardware to initialize; always succeeds.
    return true;
  }

  @override
  Future<MediaAsset?> capturePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    return path != null ? FileMediaAsset(path) : null;
  }

  /// Opens the video picker immediately.
  ///
  /// On web/desktop there is no "hold to record" — the user picks a file.
  /// The path is buffered so [stopVideoRecording] can return it.
  /// Returns true if the user selected a file.
  @override
  Future<bool> startVideoRecording() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    _pendingVideoPath = result?.files.single.path;
    return _pendingVideoPath != null;
  }

  /// Returns the asset buffered by [startVideoRecording].
  @override
  Future<MediaAsset?> stopVideoRecording() async {
    final path = _pendingVideoPath;
    _pendingVideoPath = null;
    return path != null ? FileMediaAsset(path) : null;
  }

  /// Flash is not available on this platform.
  @override
  Future<bool> toggleFlash() async => false;

  /// Camera switching is not available on this platform.
  @override
  Future<bool> switchCamera() async => false;

  @override
  Future<void> dispose() async {
    _pendingVideoPath = null;
  }
}
