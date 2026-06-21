/// Result type for a video export operation.
///
/// Use a switch expression or pattern matching to handle all cases:
/// ```dart
/// switch (result) {
///   case ExportSuccess(:final outputPath): ...
///   case ExportFailure(:final error):      ...
///   case ExportUnsupported(:final reason): ...
/// }
/// ```
sealed class ExportResult {}

/// Export completed successfully. [outputPath] is the absolute path to the MP4.
class ExportSuccess extends ExportResult {
  final String outputPath;
  ExportSuccess(this.outputPath);
}

/// Export failed due to an FFmpeg error or I/O problem.
class ExportFailure extends ExportResult {
  final String error;
  ExportFailure(this.error);
}

/// Export is not supported on this platform.
class ExportUnsupported extends ExportResult {
  final String reason;
  ExportUnsupported(this.reason);
}
