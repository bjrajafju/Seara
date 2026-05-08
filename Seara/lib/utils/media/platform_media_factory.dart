// Conditional export — routes to the correct implementation at compile time.
// Web builds use Image.network / VideoPlayerController.networkUrl.
// All other platforms use Image.file / VideoPlayerController.file (dart:io).
export 'platform_media_io.dart'
    if (dart.library.html) 'platform_media_web.dart';
