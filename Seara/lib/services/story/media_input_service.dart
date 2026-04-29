import 'package:flutter/material.dart';

/// Holds a ready-to-render preview widget and its native aspect ratio.
///
/// Produced by [MediaInputService.getPreview] so the UI never needs to
/// import package:camera or know which implementation is active.
class CameraPreviewData {
  final double aspectRatio;
  final Widget preview;
  const CameraPreviewData({required this.aspectRatio, required this.preview});
}

/// Abstract contract for media capture input.
///
/// Implementations cover mobile (live camera) and
/// web/desktop (file picker fallback).
abstract class MediaInputService {
  /// Whether a live camera preview is available.
  /// False for file-picker-based implementations.
  bool get hasCameraPreview;

  /// Returns a [CameraPreviewData] ready for rendering, or null if the
  /// service is not yet initialized or has no preview.
  CameraPreviewData? getPreview(BuildContext context);

  /// Initialize the service (request permissions, open camera, etc.).
  /// Returns true if ready to use.
  Future<bool> initialize();

  /// Capture a photo. Returns a local file path, or null on failure.
  Future<String?> capturePhoto();

  /// Begin video recording. Returns true if started successfully.
  /// On file-picker implementations, immediately opens the picker and
  /// resolves when the user selects a file (startVideoRecording and
  /// stopVideoRecording are treated as a single pick-on-start flow).
  Future<bool> startVideoRecording();

  /// Stop video recording. Returns the recorded file path, or null on failure.
  Future<String?> stopVideoRecording();

  /// Toggle flash. Returns true if flash is now on.
  /// No-op on platforms without a camera; returns false.
  Future<bool> toggleFlash();

  /// Switch between front and back camera.
  /// No-op on platforms without a camera; returns false.
  Future<bool> switchCamera();

  /// Release resources.
  Future<void> dispose();
}
