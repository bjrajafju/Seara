import 'audio_service_impl_stub.dart'
    if (dart.library.html) 'audio_service_web.dart'
    if (dart.library.io) 'audio_service_io.dart'
    as impl;

class AudioRecordingResult {
  const AudioRecordingResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

abstract class AudioService {
  Future<bool> checkPermissions();
  Future<void> startRecording();
  Future<AudioRecordingResult?> stopRecording();
  Future<void> cancelRecording();
  Future<void> dispose();
}

AudioService createAudioService() => impl.createAudioService();
