// Conditional export — routes to the correct implementation at compile time.
// Web builds use dart:html for browser downloads.
// All other platforms use dart:io + path_provider.
export 'export_saver_io.dart' if (dart.library.html) 'export_saver_web.dart';
