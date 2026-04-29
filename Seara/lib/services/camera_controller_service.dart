import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle camera initialization, capturing photos, and recording videos.
class CameraControllerService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  CameraController? get controller => _controller;

  /// Requests permissions and initializes the camera.
  /// Returns true if successful, false otherwise.
  Future<bool> initialize() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus != PermissionStatus.granted) {
      return false;
    }

    await Permission.microphone.request();
    // Proceed even if mic is denied; video just won't have audio if denied.
    
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return false;
      }
      return await _initCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _initCamera(CameraDescription description) async {
    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Switches between front and back cameras.
  /// Returns true if successful.
  Future<bool> switchCamera() async {
    if (_cameras.length < 2) return false;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    return _initCamera(_cameras[_currentCameraIndex]);
  }

  /// Toggles the flash mode between always on and off.
  /// Returns true if flash is now on, false if off or failed.
  Future<bool> toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return false;

    final currentMode = _controller!.value.flashMode;
    final newMode = currentMode == FlashMode.off ? FlashMode.always : FlashMode.off;
    
    try {
      await _controller!.setFlashMode(newMode);
      return newMode == FlashMode.always;
    } catch (e) {
      return false;
    }
  }

  /// Captures a photo and returns the file path, or null if failed.
  Future<String?> takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) {
      return null;
    }

    try {
      final file = await _controller!.takePicture();
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Starts video recording. Returns true if started successfully.
  Future<bool> startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isRecordingVideo) {
      return false;
    }

    try {
      await _controller!.startVideoRecording();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stops video recording and returns the file path, or null if failed.
  Future<String?> stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || !_controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      final file = await _controller!.stopVideoRecording();
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Disposes the camera controller.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
