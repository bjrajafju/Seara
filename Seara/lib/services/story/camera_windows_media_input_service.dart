import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../models/story/media_asset.dart';
import '../camera_controller_service.dart';
import 'camera_permission_service.dart';
import 'media_input_service.dart';

/// [MediaInputService] for Windows desktop.
///
/// Backed by camera_windows (must be added explicitly to pubspec.yaml;
/// it is not an endorsed federated plugin).
///
/// Limitations (camera_windows constraints):
/// - Flash is not implemented — toggleFlash always returns false.
/// - Pause/resume video recording is not supported.
/// - Device orientation detection is not available.
class CameraWindowsMediaInputService implements MediaInputService {
  final CameraControllerService _camera = CameraControllerService();
  static const _permissions = WindowsPermissionService();

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
    // WindowsPermissionService is a no-op; camera_windows manages OS permissions.
    // A CameraException thrown by CameraController.initialize() signals denial.
    await _permissions.requestPermissions();
    return _camera.initialize();
  }

  @override
  Future<MediaAsset?> capturePhoto() async {
    final xFile = await _camera.takePictureXFile();
    if (xFile == null) return null;
    return FileMediaAsset(xFile.path);
  }

  @override
  Future<bool> startVideoRecording() => _camera.startVideoRecording();

  @override
  Future<MediaAsset?> stopVideoRecording() async {
    final xFile = await _camera.stopVideoRecordingXFile();
    if (xFile == null) return null;
    return FileMediaAsset(xFile.path);
  }

  /// Flash is not implemented in camera_windows — always returns false.
  @override
  Future<bool> toggleFlash() async => false;

  @override
  Future<bool> switchCamera() => _camera.switchCamera();

  @override
  Future<void> dispose() => _camera.dispose();
}
