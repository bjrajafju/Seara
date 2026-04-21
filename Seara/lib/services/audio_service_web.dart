import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:record/record.dart';

import 'audio_service.dart';

class _AudioServiceWeb implements AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  @override
  /// Check permissions
  Future<bool> checkPermissions() async {
    return _recorder.hasPermission();
  }

  @override
  /// Starts recording
  Future<void> startRecording() async {
    final path = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.opus),
      path: path,
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

    final bytes = await _readBytesFromPath(path);
    if (bytes == null || bytes.isEmpty) return null;

    return AudioRecordingResult(
      bytes: bytes,
      fileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.webm',
      mimeType: 'audio/webm',
    );
  }

  /// Read bytes from path
  Future<Uint8List?> _readBytesFromPath(String path) async {
    if (path.startsWith('data:')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex <= 0) return null;
      final base64Payload = path.substring(commaIndex + 1);
      return base64Decode(base64Payload);
    }

    if (path.startsWith('blob:') || path.startsWith('http')) {
      final req = await html.HttpRequest.request(
        path,
        method: 'GET',
        responseType: 'arraybuffer',
      );
      final buffer = req.response as ByteBuffer?;
      if (buffer == null) return null;
      return Uint8List.view(buffer);
    }

    return null;
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

AudioService createAudioService() => _AudioServiceWeb();
