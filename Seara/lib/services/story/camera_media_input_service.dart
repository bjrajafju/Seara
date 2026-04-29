import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../camera_controller_service.dart';
import 'media_input_service.dart';

/// Mobile implementation of [MediaInputService] backed by the camera plugin.
class CameraMediaInputService implements MediaInputService {
  final CameraControllerService _camera = CameraControllerService();

  @override
  bool get hasCameraPreview => true;

  @override
  CameraPreviewData? getPreview(BuildContext context) {
    final controller = _camera.controller;
    if (controller == null || !controller.value.isInitialized) return null;

    final mediaSize = MediaQuery.of(context).size;
    final camAspect = controller.value.aspectRatio;
    final scale = mediaSize.aspectRatio > camAspect
        ? mediaSize.aspectRatio / camAspect
        : camAspect / mediaSize.aspectRatio;

    return CameraPreviewData(
      aspectRatio: camAspect,
      preview: Transform.scale(
        scale: scale,
        child: Center(
          child: AspectRatio(
            aspectRatio: camAspect,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Future<bool> initialize() => _camera.initialize();

  @override
  Future<String?> capturePhoto() => _camera.takePhoto();

  @override
  Future<bool> startVideoRecording() => _camera.startVideoRecording();

  @override
  Future<String?> stopVideoRecording() => _camera.stopVideoRecording();

  @override
  Future<bool> toggleFlash() => _camera.toggleFlash();

  @override
  Future<bool> switchCamera() => _camera.switchCamera();

  @override
  Future<void> dispose() => _camera.dispose();
}
