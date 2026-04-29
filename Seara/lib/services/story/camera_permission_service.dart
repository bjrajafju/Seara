/// Strategy for requesting camera (and microphone) permissions
/// before camera hardware is initialized.
///
/// Platform implementations differ: mobile uses permission_handler;
/// web lets the browser prompt natively; Windows relies on the plugin.
abstract class CameraPermissionService {
  /// Returns true when capture may proceed.
  Future<bool> requestPermissions();
}

/// Web — no-op. The browser prompts natively on the first getUserMedia call.
class WebPermissionService implements CameraPermissionService {
  const WebPermissionService();

  @override
  Future<bool> requestPermissions() async => true;
}

/// Windows — the camera_windows plugin manages OS permissions internally.
/// A CameraException during controller.initialize() signals denial.
class WindowsPermissionService implements CameraPermissionService {
  const WindowsPermissionService();

  @override
  Future<bool> requestPermissions() async => true;
}

// MobilePermissionService lives in camera_mobile_media_input_service.dart
// alongside its permission_handler import, which must not be compiled on web.
