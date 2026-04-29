import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../models/story/media_asset.dart';
import '../camera_controller_service.dart';
import 'camera_permission_service.dart';
import 'media_input_service.dart';

/// [MediaInputService] for web browsers.
///
/// Backed by camera_web (auto-bundled with package:camera on web).
/// Photos are returned as [BytesMediaAsset] (blob read into memory).
/// Videos are returned as [StreamMediaAsset] (temporary blob URL).
/// Flash is not supported; camera switching uses facingMode.
class CameraWebMediaInputService implements MediaInputService {
  final CameraControllerService _camera = CameraControllerService();
  static const _permissions = WebPermissionService();

  @override
  bool get hasCameraPreview => true;

  @override
  CameraPreviewData? getPreview(BuildContext context) {
    final controller = _camera.controller;
    if (controller == null || !controller.value.isInitialized) return null;

    final camAspect = controller.value.aspectRatio;
    return CameraPreviewData(
      aspectRatio: camAspect,
      builder: (ctx) {
        final mediaSize = MediaQuery.of(ctx).size;
        final scale = mediaSize.aspectRatio > camAspect
            ? mediaSize.aspectRatio / camAspect
            : camAspect / mediaSize.aspectRatio;
        return Transform.scale(
          scale: scale,
          child: Center(
            child: AspectRatio(
              aspectRatio: camAspect,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }

  @override
  Future<bool> initialize() async {
    await _permissions.requestPermissions(); // no-op; browser prompts
    return _camera.initialize();
  }

  /// Captures a photo and returns it as in-memory bytes.
  @override
  Future<MediaAsset?> capturePhoto() async {
    final xFile = await _camera.takePictureXFile();
    if (xFile == null) return null;
    final bytes = await xFile.readAsBytes();
    return BytesMediaAsset(bytes: bytes, mimeType: 'image/jpeg');
  }

  @override
  Future<bool> startVideoRecording() => _camera.startVideoRecording();

  /// Stops recording and returns the temporary blob URL for the video.
  @override
  Future<MediaAsset?> stopVideoRecording() async {
    final xFile = await _camera.stopVideoRecordingXFile();
    if (xFile == null) return null;
    // camera_web returns a blob: URL as XFile.path for video.
    return StreamMediaAsset(url: xFile.path, mimeType: 'video/webm');
  }

  /// Flash is not exposed by the browser camera API — always returns false.
  @override
  Future<bool> toggleFlash() async => false;

  @override
  Future<bool> switchCamera() => _camera.switchCamera();

  @override
  Future<void> dispose() => _camera.dispose();
}
