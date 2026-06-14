import 'package:flutter/material.dart';
import '../../models/story/media_asset.dart';

/// Holds a builder for the camera preview widget plus the camera's aspect ratio.
///
/// Using a [WidgetBuilder] instead of a concrete [Widget] avoids stale-context
/// issues when the service produces the preview before [BuildContext] is ready.
class CameraPreviewData {
  final double aspectRatio;

  /// Builds the preview widget for the given [BuildContext].
  final WidgetBuilder builder;

  const CameraPreviewData({required this.aspectRatio, required this.builder});
}

/// Abstract contract for media capture input.
///
/// Concrete implementations:
/// - [CameraMobileMediaInputService] — iOS / Android
/// - [CameraWebMediaInputService]    — Web (camera_web)
/// - [CameraWindowsMediaInputService] — Windows (camera_windows)
abstract class MediaInputService {
  /// Whether a live camera preview stream is available.
  bool get hasCameraPreview;

  bool get isFrontCamera;

  /// Returns preview data for rendering, or null if not yet initialised.
  CameraPreviewData? getPreview(BuildContext context);

  /// Initialises hardware and requests permissions.
  /// Returns true if ready to capture.
  Future<bool> initialize();

  /// Captures a still photo. Returns a [MediaAsset] on success, null on failure.
  Future<MediaAsset?> capturePhoto();

  /// Begins video recording. Returns true if started successfully.
  Future<bool> startVideoRecording();

  /// Stops video recording. Returns a [MediaAsset] on success, null on failure.
  Future<MediaAsset?> stopVideoRecording();

  /// Toggles flash. Returns true if flash is now on.
  /// Returns false on platforms / hardware where flash is unavailable.
  Future<bool> toggleFlash();

  Future<bool> isFlashOn();

  /// Switches between available cameras (e.g. front ↔ back).
  /// Returns false if only one camera is present or switching failed.
  Future<bool> switchCamera();

  Future<bool> hasTwoCameras();

  /// Releases all held resources.
  Future<void> dispose();
}
