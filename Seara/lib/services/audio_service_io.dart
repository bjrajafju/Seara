import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'audio_service.dart';

class _AudioServiceIo implements AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;

  @override
  /// Check permissions
  Future<bool> checkPermissions() async {
    return _recorder.hasPermission();
  }

  @override
  /// Starts recording
  Future<void> startRecording() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _recordingPath = '${tempDir.path}/audio_$timestamp.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    _isRecording = true;
  }

  @override
  /// Stops recording
  Future<AudioRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final fileName = p.basename(path);
    return AudioRecordingResult(
      bytes: bytes,
      fileName: fileName.isEmpty
          ? 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : fileName,
      mimeType: 'audio/mp4',
    );
  }

  @override
  /// Cancel recording
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

AudioService createAudioService() => _AudioServiceIo();
