import 'dart:io';
import 'package:flutter/foundation.dart';
import 'camera_media_input_service.dart';
import 'file_picker_media_input_service.dart';
import 'media_input_service.dart';

/// Returns the appropriate [MediaInputService] for the current platform.
///
/// Web and desktop use the file picker; mobile uses the live camera.
MediaInputService createMediaInputService() {
  if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return FilePickerMediaInputService();
  }
  return CameraMediaInputService();
}
