import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';

/// Web implementation of FFmpeg execution using FFmpeg WASM.
/// 
/// We use an 'eval' bridge to avoid index.html modifications while 
/// maintaining the Phase 4 requirement of using FFmpeg WASM only.
Future<bool> executeFFmpegCommand(String command) async {
  try {
    final completer = Completer<bool>();
    
    // Create a callback for JS to notify Dart
    js.context['ffmpegCallback'] = (bool success) {
      if (!completer.isCompleted) completer.complete(success);
    };

    js.context.callMethod('eval', [
      '''
      (async function() {
        try {
          // 1. Load FFmpeg if not already loaded
          if (typeof FFmpeg === 'undefined') {
            await new Promise((resolve, reject) => {
              const script = document.createElement('script');
              script.src = 'https://unpkg.com/@ffmpeg/ffmpeg@0.11.6/dist/ffmpeg.min.js';
              script.onload = resolve;
              script.onerror = reject;
              document.head.appendChild(script);
            });
          }

          const { createFFmpeg, fetchFile } = FFmpeg;
          if (!window._ffmpeg) {
            window._ffmpeg = createFFmpeg({ log: true });
          }
          
          const ffmpeg = window._ffmpeg;
          if (!ffmpeg.isLoaded()) {
            await ffmpeg.load();
          }

          // 2. Write files from window._ffmpeg_input_files (set by Dart)
          if (window._ffmpeg_input_files) {
            for (const [name, bytes] of Object.entries(window._ffmpeg_input_files)) {
              ffmpeg.FS('writeFile', name, bytes);
            }
          }

          // 3. Run command
          // The command looks like: -y -i input.mp4 ...
          // We need to split it for FFmpeg.run()
          const args = "${command.replaceAll('"', '\\"')}".split(' ').filter(x => x.length > 0);
          
          await ffmpeg.run(...args);

          // 4. Extract result if successful
          // We assume the last argument is the output path
          const outputName = args[args.length - 1];
          try {
            const data = ffmpeg.FS('readFile', outputName);
            window._ffmpeg_output = data;
          } catch (e) {
            console.error("Failed to read output file:", e);
          }

          window.ffmpegCallback(true);
        } catch (e) {
          console.error("FFmpeg WASM error:", e);
          window.ffmpegCallback(false);
        }
      })();
      '''
    ]);

    return await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => false,
    );
  } catch (e) {
    // ignore: avoid_print
    print('[FFmpeg/Web] Execution failed: $e');
    return false;
  }
}

/// Web stub: always returns null (binary is in-memory WASM).
Future<String?> resolveFFmpegPath() async => null;

/// Helper to get the result from the JS layer.
Uint8List? getFFmpegOutput() {
  final dynamic output = js.context['_ffmpeg_output'];
  if (output == null) return null;
  return output as Uint8List;
}

/// Helper to set input files for the JS layer.
void setFFmpegInputFiles(Map<String, Uint8List> files) {
  js.context['_ffmpeg_input_files'] = js.JsObject.jsify(files);
}
