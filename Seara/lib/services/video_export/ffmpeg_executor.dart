// Conditional export: web builds use the stub, all others use the real IO executor.
// This is the same pattern used in export_saver.dart and platform_media_factory.dart.
export 'ffmpeg_executor_io.dart'
    if (dart.library.html) 'ffmpeg_executor_web.dart';
