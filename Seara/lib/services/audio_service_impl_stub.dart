import 'audio_service.dart';

// Creates a no-op audio service implementation
AudioService createAudioService() {
  throw UnsupportedError('Audio recording is not supported on this platform.');
}
