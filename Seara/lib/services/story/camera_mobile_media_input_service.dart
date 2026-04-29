import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/story/media_asset.dart';
import '../camera_controller_service.dart';
import 'camera_permission_service.dart';
import 'media_input_service.dart';

/// [CameraPermissionService] implementation for Android and iOS.
///
/// Requests camera and microphone access via permission_handler.
/// Microphone denial is non-fatal; video records without audio.
class MobilePermissionService implements CameraPermissionService {
  const MobilePermissionService();

  @override
  Future<bool> requestPermissions() async {
    final camera = await Permission.camera.request();
    if (camera != PermissionStatus.granted) return false;
    await Permission.microphone.request(); // non-fatal if denied
    return true;
  }
}

/// [MediaInputService] for Android and iOS.
///
/// Delivers full camera features: live preview, photo, video,
/// flash toggle, and camera switching.
class CameraMobileMediaInputService implements MediaInputService {
  final CameraControllerService _camera = CameraControllerService();
  static const _permissions = MobilePermissionService();

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
    final granted = await _permissions.requestPermissions();
    if (!granted) return false;
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

  @override
  Future<bool> toggleFlash() => _camera.toggleFlash();

  @override
  Future<bool> switchCamera() => _camera.switchCamera();

  @override
  Future<void> dispose() => _camera.dispose();
}
