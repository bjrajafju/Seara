import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  /// Holds the selected asset (path on native, bytes/blob on web).
  MediaAsset? _pendingAsset;

  @override
  bool get hasCameraPreview => false;

  @override
  CameraPreviewData? getPreview(BuildContext context) {
    return null;
  }

  @override
  Future<bool> initialize() async {
    return true;
  }

  @override
  Future<MediaAsset?> capturePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    if (kIsWeb) {
      if (file.bytes == null) return null;
      return BytesMediaAsset(file.bytes!, 'image/jpeg');
    } else {
      if (file.path == null) return null;
      return FileMediaAsset(file.path!);
    }
  }

  @override
  Future<bool> startVideoRecording() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return false;
    final file = result.files.first;

    if (kIsWeb) {
      // For web video, we usually want a blob URL.
      // PlatformFile.path on web IS the blob URL in some versions of file_picker,
      // but the safer way is to check.
      // However, Seara's StoryMedia expects a filePath or bytes.
      // We'll store it as a FileMediaAsset if a path (blob URL) is present,
      // or BytesMediaAsset if not.
      if (file.bytes != null) {
        _pendingAsset = BytesMediaAsset(file.bytes!, 'video/mp4');
      } else {
        // Fallback to path if bytes are null (might be a blob URL)
        final path = file.path;
        if (path != null) {
          _pendingAsset = FileMediaAsset(path);
        }
      }
    } else {
      final path = file.path;
      if (path != null) {
        _pendingAsset = FileMediaAsset(path);
      }
    }

    return _pendingAsset != null;
  }

  @override
  Future<MediaAsset?> stopVideoRecording() async {
    final asset = _pendingAsset;
    _pendingAsset = null;
    return asset;
  }

  @override
  Future<bool> toggleFlash() async => false;

  @override
  Future<bool> switchCamera() async => false;

  @override
  Future<void> dispose() async {
    _pendingAsset = null;
  }
}
