import 'dart:io' show File;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/story/media_asset.dart';
import '../camera_controller_service.dart';
import 'camera_permission_service.dart';
import 'media_input_service.dart';
import '../../utils/media/image_flip_helper.dart';

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

    return CameraPreviewData(
      aspectRatio: controller.value.aspectRatio,
      builder: (ctx) {
        return ClipRect(child: CameraPreview(controller));
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

    if (_camera.isFrontCamera) {
      try {
        final file = File(xFile.path);
        var bytes = await file.readAsBytes();
        bytes = ImageFlipHelper.flipHorizontal(bytes, 'image/jpeg');
        await file.writeAsBytes(bytes);
      } catch (e) {
        debugPrint(
          'CameraMobileMediaInputService: Error flipping front camera photo: $e',
        );
      }
    }

    return FileMediaAsset(xFile.path, isMirrored: false);
  }

  @override
  Future<bool> startVideoRecording() => _camera.startVideoRecording();

  @override
  Future<MediaAsset?> stopVideoRecording() async {
    try {
      final xFile = await _camera.stopVideoRecordingXFile();

      if (xFile == null) {
        debugPrint('STOP VIDEO: null file returned');
        return null;
      }

      return FileMediaAsset(xFile.path, isMirrored: _camera.isFrontCamera);
    } catch (e) {
      debugPrint('STOP VIDEO ERROR: $e');
      return null;
    }
  }

  @override
  Future<bool> toggleFlash() => _camera.toggleFlash();

  @override
  Future<bool> isFlashOn() async {
    final c = _camera.controller;
    if (c == null || !c.value.isInitialized) return false;
    return c.value.flashMode != FlashMode.off;
  }

  @override
  bool get isFrontCamera => _camera.isFrontCamera;

  @override
  Future<bool> switchCamera() => _camera.switchCamera();

  @override
  Future<bool> hasTwoCameras() => _camera.hasTwoCameras();

  @override
  Future<void> dispose() => _camera.dispose();
}
