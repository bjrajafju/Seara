// Conditional import entry point — compile-time platform resolution.
//
// dart.library.html is only present on web → factory_web.dart
// All other (native) targets → factory_io.dart
//
// No runtime Platform checks exist in this file.
import 'media_input_service_factory_io.dart'
    if (dart.library.html) 'media_input_service_factory_web.dart'
    as factory_impl;

import 'media_input_service.dart';

/// Returns the [MediaInputService] appropriate for the current platform.
///
/// Platform resolution is compile-time via conditional imports:
/// - Web    → [CameraWebMediaInputService]
/// - Windows → [CameraWindowsMediaInputService]
/// - Mobile  → [CameraMobileMediaInputService]
MediaInputService createMediaInputService() => factory_impl.create();
