// Conditional export: routes to dart:io implementation on native platforms,
// or a no-op stub on web (where dart:io is unavailable).
export 'io_file_helper_io.dart'
    if (dart.library.html) 'io_file_helper_web.dart';
