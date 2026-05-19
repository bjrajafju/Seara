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
        return LayoutBuilder(
          builder: (context, constraints) {
            // BoxFit.cover behavior within the available 9:16 viewport
            // provided by StoryViewport.
            return ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth / camAspect,
                  child: CameraPreview(controller),
                ),
              ),
            );
          },
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

    // Web camera plugin (camera_web) already returns front camera photos mirrored
    // to match the screen preview, so we do not need to physically flip it or double-mirror.
    return BytesMediaAsset(
      bytes: bytes,
      mimeType: 'image/jpeg',
      isMirrored: false,
    );
  }

  @override
  Future<bool> startVideoRecording() async => false;

  @override
  Future<MediaAsset?> stopVideoRecording() async => null;

  /// Flash is not exposed by the browser camera API — always returns false.
  @override
  Future<bool> toggleFlash() async => false;

  @override
  Future<bool> switchCamera() => _camera.switchCamera();

  @override
  Future<void> dispose() => _camera.dispose();
}
