/// Web stub for FFmpeg executor.
///
/// Video stories are not supported on Web.
Future<bool> executeFFmpegCommand(String command) async {
  return false;
}

Future<String?> resolveFFmpegPath() async {
  return null;
}
