import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// ffmpeg_kit_flutter_new supports Android, iOS, and macOS.
// The Dart layer compiles on all platforms (method channels are platform-agnostic).
// On Windows we guard with Platform.isWindows and never invoke the channel,
// so MissingPluginException is never thrown at runtime.
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart' as fk;
import 'package:ffmpeg_kit_flutter_new/return_code.dart' as rc;

/// Executes an FFmpeg command string and returns true on success.
///
/// - **Windows**: runs the bundled `ffmpeg.exe` via `dart:io Process.run`.
/// - **Android / iOS / macOS**: delegates to `ffmpeg_kit_flutter_new`.
///
/// The command string must contain only the arguments — do NOT include
/// the `ffmpeg` binary name. Example:
/// ```
/// -y -i input.mp4 -i overlay.png -filter_complex ... output.mp4
/// ```
Future<bool> executeFFmpegCommand(String command) async {
  if (Platform.isWindows) {
    return _executeWindows(command);
  }
  return _executeMobile(command);
}

/// Returns the path to the ffmpeg executable on Windows.
/// Returns null on mobile/macOS (binary is embedded in the native library).
Future<String?> resolveFFmpegPath() async {
  if (!Platform.isWindows) return null;
  return _windowsFFmpegPath();
}

//  Windows: dart:io Process.run with bundled ffmpeg.exe

Future<bool> _executeWindows(String command) async {
  final ffmpegPath = await _windowsFFmpegPath();
  final args = _parseArgs(command);

  final result = await Process.run(ffmpegPath, args, runInShell: false);

  if (result.exitCode != 0) {
    // ignore: avoid_print
    print('[FFmpeg/Win] stderr:\n${result.stderr}');
  }
  return result.exitCode == 0;
}

/// Extracts `ffmpeg.exe` from Flutter assets on first run and caches it in
/// the system temporary directory for subsequent invocations.
Future<String> _windowsFFmpegPath() async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/seara_ffmpeg.exe');

  if (!await file.exists()) {
    final data = await rootBundle.load('assets/ffmpeg/ffmpeg.exe');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  return file.path;
}

//  Mobile / macOS: ffmpeg_kit_flutter_new

Future<bool> _executeMobile(String command) async {
  final session = await fk.FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  final success = rc.ReturnCode.isSuccess(returnCode);

  if (!success) {
    final output = await session.getOutput();
    // ignore: avoid_print
    print('[FFmpeg/Mobile] output:\n$output');
  }
  return success;
}

//  Argument parser

/// Splits a command string into individual arguments, respecting quoted tokens.
///
/// `'-i "C:/path with spaces/file.mp4" -c copy out.mp4'`
/// → `['-i', 'C:/path with spaces/file.mp4', '-c', 'copy', 'out.mp4']`
List<String> _parseArgs(String command) {
  final args = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < command.length; i++) {
    final ch = command[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ' ' && !inQuotes) {
      if (buf.isNotEmpty) {
        args.add(buf.toString());
        buf.clear();
      }
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) args.add(buf.toString());
  return args;
}
