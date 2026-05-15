import 'package:camera/camera.dart';

/// Low-level wrapper around [CameraController].
///
/// Permission requests have been removed — each platform's [MediaInputService]
/// calls its own [CameraPermissionService] before calling [initialize].
class CameraControllerService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  CameraController? get controller => _controller;

  /// Returns true if the current camera is front-facing.
  bool get isFrontCamera {
    if (_cameras.isEmpty) return false;
    return _cameras[_currentCameraIndex].lensDirection ==
        CameraLensDirection.front;
  }

  /// Initialises the first available camera. Returns true on success.
  Future<bool> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;
      return await _initCamera(_cameras[_currentCameraIndex]);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _initCamera(CameraDescription description) async {
    await _controller?.dispose();
    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await _controller!.initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Camera controls
  // ---------------------------------------------------------------------------

  Future<bool> switchCamera() async {
    if (_cameras.length < 2) return false;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    return _initCamera(_cameras[_currentCameraIndex]);
  }

  /// Toggles flash between always-on and off.
  /// Returns false on platforms where flash is not supported.
  Future<bool> toggleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return false;
    final next = c.value.flashMode == FlashMode.off
        ? FlashMode.always
        : FlashMode.off;
    try {
      await c.setFlashMode(next);
      return next == FlashMode.always;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Capture — XFile-returning variants used by all three platform services
  // ---------------------------------------------------------------------------

  /// Captures a still image. Returns the [XFile] on success, null otherwise.
  Future<XFile?> takePictureXFile() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) {
      return null;
    }
    try {
      return await c.takePicture();
    } catch (_) {
      return null;
    }
  }

  /// Starts video recording. Returns true if started successfully.
  Future<bool> startVideoRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) {
      return false;
    }
    try {
      await c.startVideoRecording();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops video recording. Returns the [XFile] on success, null otherwise.
  Future<XFile?> stopVideoRecordingXFile() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !c.value.isRecordingVideo) {
      return null;
    }
    try {
      return await c.stopVideoRecording();
    } catch (_) {
      return null;
    }
  }

  /// Disposes the controller and releases hardware resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
