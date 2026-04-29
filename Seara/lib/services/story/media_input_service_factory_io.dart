// IO (native) factory stub — compiled on mobile and Windows.
// dart:io is available here; dart.library.html is NOT present.
import 'dart:io';

import 'camera_mobile_media_input_service.dart';
import 'camera_windows_media_input_service.dart';
import 'media_input_service.dart';

/// Returns the correct native camera service based on the current OS.
///
/// A single [Platform.isWindows] check is unavoidable here: Dart's conditional
/// import system can only distinguish web vs native, not Windows vs mobile.
/// This is the only runtime branch in the entire factory chain.
MediaInputService create() {
  if (Platform.isWindows) return CameraWindowsMediaInputService();
  return CameraMobileMediaInputService();
}
