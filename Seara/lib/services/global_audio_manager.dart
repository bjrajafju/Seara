import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

const String kAttachmentPreviewMessageId = '__seara_attachment_preview__';

class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this.bytes, {this.mimeType});

  final Uint8List bytes;
  final String? mimeType;

  @override
  /// Request
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final rangeStart = start ?? 0;
    final rangeEnd = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: rangeEnd - rangeStart,
      offset: rangeStart,
      stream: Stream.value(bytes.sublist(rangeStart, rangeEnd)),
      contentType: mimeType ?? 'audio/mpeg',
    );
  }
}

class GlobalAudioManager {
  GlobalAudioManager._();
  static final GlobalAudioManager instance = GlobalAudioManager._();

  AudioPlayer? _player;
  String? _currentMessageId;
  bool _sessionConfigured = false;

  bool _rewindingAfterComplete = false;

  Future<void> _tail = Future<void>.value();
  int _playRequestId = 0;
  double _speed = 1.0;

  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  PlayerState _lastPlayerState = PlayerState(false, ProcessingState.idle);
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  String? _lastActiveMessageId;

  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _activeIdController = StreamController<String?>.broadcast();

  Stream<PlayerState> get playerStateStream => _stateController.stream;

  Stream<Duration> get positionStream => _positionController.stream;

  Stream<Duration> get durationStream => _durationController.stream;

  Stream<String?> get activeMessageIdStream => _activeIdController.stream;

  String? get currentMessageId => _currentMessageId;

  PlayerState get lastPlayerState => _lastPlayerState;

  Duration get lastPosition => _lastPosition;

  Duration get lastDuration => _lastDuration;

  String? get lastActiveMessageId => _lastActiveMessageId;

  /// Run
  Future<void> _run(Future<void> Function() fn) {
    final c = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await fn();
        if (!c.isCompleted) c.complete();
      } catch (e, st) {
        if (!c.isCompleted) c.completeError(e, st);
      }
    });
    return c.future;
  }

  /// Returns whether playing
  bool isPlaying(String messageId) {
    if (_currentMessageId != messageId) return false;
    final p = _player;
    if (p == null) return false;
    return p.playing &&
        p.processingState != ProcessingState.completed &&
        p.processingState != ProcessingState.idle;
  }

  /// Position for
  Duration positionFor(String messageId) {
    if (_currentMessageId != messageId || _player == null) return Duration.zero;
    return _player!.position;
  }

  /// Duration for
  Duration? durationFor(String messageId) {
    if (_currentMessageId != messageId || _player == null) return null;
    return _player!.duration;
  }

  /// Looks like http url
  static bool _looksLikeHttpUrl(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  /// Play url
  Future<void> playUrl(String messageId, String url) async {
    if (!_looksLikeHttpUrl(url)) {
      debugPrint(
        '[GlobalAudioManager] playUrl: expected http(s) URL, got: $url',
      );
      return;
    }
    await _interruptAndPlay(messageId, AudioSource.uri(Uri.parse(url.trim())));
  }

  /// Play file
  Future<void> playFile(String messageId, String filePath) async {
    if (_looksLikeHttpUrl(filePath)) {
      debugPrint(
        '[GlobalAudioManager] playFile: expected file path, got URL-like: $filePath',
      );
      return;
    }
    await _interruptAndPlay(messageId, AudioSource.file(filePath.trim()));
  }

  Future<void> playBytes(
    String messageId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    await _interruptAndPlay(
      messageId,
      _BytesAudioSource(bytes, mimeType: mimeType),
    );
  }

  /// Prepare from file
  Future<void> prepareFromFile(
    String messageId,
    String filePath,
  ) => _run(() async {
    if (_looksLikeHttpUrl(filePath)) {
      debugPrint(
        '[GlobalAudioManager] prepareFromFile: expected file path, got URL-like: $filePath',
      );
      return;
    }
    await _stopAndReset();
    await _loadPaused(messageId, AudioSource.file(filePath.trim()));
  });

  Future<void> prepareFromBytes(
    String messageId,
    Uint8List bytes, {
    String? mimeType,
  }) =>
      /// Run
      _run(() async {
        await _stopAndReset();
        await _loadPaused(
          messageId,
          _BytesAudioSource(bytes, mimeType: mimeType),
        );
      });

  /// Pause
  Future<void> pause() {
    final p = _player;

    /// Run
    return _run(() async {
      if (p == null || !identical(_player, p)) return;
      try {
        await p.pause();
        _lastPlayerState = p.playerState;
        if (!_stateController.isClosed) _stateController.add(_lastPlayerState);
      } catch (e) {
        debugPrint('[GlobalAudioManager] pause error: $e');
      }
    });
  }

  /// Resume
  Future<void> resume() {
    final p = _player;

    /// Run
    return _run(() async {
      if (p == null || !identical(_player, p)) return;
      try {
        await p.play();
        await _applySpeed(p);
        _lastPlayerState = p.playerState;
        if (!_stateController.isClosed) _stateController.add(_lastPlayerState);
      } catch (e) {
        debugPrint('[GlobalAudioManager] resume error: $e');
      }
    });
  }

  /// Seek
  Future<void> seek(Duration position) {
    final p = _player;

    /// Run
    return _run(() async {
      if (p == null || !identical(_player, p)) return;
      try {
        await p.seek(position);
        _lastPosition = p.position;
        if (!_positionController.isClosed)
          _positionController.add(_lastPosition);
        _lastPlayerState = p.playerState;
        if (!_stateController.isClosed) _stateController.add(_lastPlayerState);
      } catch (e) {
        debugPrint('[GlobalAudioManager] seek error: $e');
      }
    });
  }

  /// Set speed
  Future<void> setSpeed(double speed) {
    _speed = speed;
    final p = _player;

    /// Run
    return _run(() async {
      if (p == null || !identical(_player, p)) return;
      try {
        await _applySpeed(p);
      } catch (e) {
        debugPrint('[GlobalAudioManager] setSpeed error: $e');
      }
    });
  }

  Future<void> stop() => _run(_stopAndReset);

  Future<void> clearCurrent() => _run(_stopAndReset);

  /// Interrupt and play
  Future<void> _interruptAndPlay(String messageId, AudioSource source) async {
    final requestId = ++_playRequestId;
    await _disposeCurrentPlayerOnly();
    if (requestId != _playRequestId) return;
    _publishResetState();
    await _loadAndPlay(messageId, source, requestId: requestId);
  }

  Future<void> _loadAndPlay(
    String messageId,
    AudioSource source, {
    required int requestId,
  }) async {
    _currentMessageId = messageId;
    _lastActiveMessageId = messageId;
    if (!_activeIdController.isClosed) _activeIdController.add(messageId);

    final player = AudioPlayer();
    _player = player;
    _attachPlayerSubscriptions(player);

    try {
      await _configureSession();
      await player.setLoopMode(LoopMode.off);
      await player.setAudioSource(source);
      if (requestId != _playRequestId || !identical(_player, player)) {
        await player.dispose();
        return;
      }
      await player.play();
      await _applySpeed(player);
    } catch (e) {
      debugPrint('[GlobalAudioManager] load/play error: $e');
      if (requestId == _playRequestId && identical(_player, player)) {
        await _stopAndReset();
      } else {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  /// Loads paused
  Future<void> _loadPaused(String messageId, AudioSource source) async {
    _currentMessageId = messageId;
    _lastActiveMessageId = messageId;
    if (!_activeIdController.isClosed) _activeIdController.add(messageId);

    final player = AudioPlayer();
    _player = player;
    _attachPlayerSubscriptions(player);

    try {
      await _configureSession();
      await player.setLoopMode(LoopMode.off);
      await player.setAudioSource(source);
    } catch (e) {
      debugPrint('[GlobalAudioManager] prepare error: $e');
      await _stopAndReset();
    }
  }

  /// Attach player subscriptions
  void _attachPlayerSubscriptions(AudioPlayer player) {
    _cancelPlayerSubscriptions();

    _playerSubscriptions.add(
      player.playerStateStream.listen((state) {
        if (!identical(_player, player)) return;
        _onPlayerState(state);
      }),
    );
    _playerSubscriptions.add(
      player.positionStream.listen((pos) {
        if (!identical(_player, player)) return;
        _lastPosition = pos;
        if (!_positionController.isClosed) _positionController.add(pos);
      }),
    );
    _playerSubscriptions.add(
      player.durationStream.listen((dur) {
        if (!identical(_player, player)) return;
        final d = dur ?? Duration.zero;
        _lastDuration = d;
        if (!_durationController.isClosed) _durationController.add(d);
      }),
    );
  }

  /// Handles player state
  void _onPlayerState(PlayerState state) {
    _lastPlayerState = state;
    if (!_stateController.isClosed) _stateController.add(state);

    if (state.processingState == ProcessingState.completed) {
      if (_rewindingAfterComplete) return;
      unawaited(_handlePlaybackCompleted());
    }
  }

  /// Handles playback completed
  Future<void> _handlePlaybackCompleted() => _run(() async {
    final p = _player;
    if (p == null || _rewindingAfterComplete) return;
    _rewindingAfterComplete = true;
    try {
      await p.seek(Duration.zero);
      await p.pause();
      final st = p.playerState;
      _lastPlayerState = st;
      if (!_stateController.isClosed) _stateController.add(st);
      final pos = p.position;
      _lastPosition = pos;
      if (!_positionController.isClosed) _positionController.add(pos);
    } catch (e) {
      debugPrint('[GlobalAudioManager] completion rewind error: $e');
    } finally {
      _rewindingAfterComplete = false;
    }
  });

  /// Cancel player subscriptions
  void _cancelPlayerSubscriptions() {
    for (final s in _playerSubscriptions) {
      unawaited(s.cancel());
    }
    _playerSubscriptions.clear();
  }

  /// Dispose current player only
  Future<void> _disposeCurrentPlayerOnly() async {
    _cancelPlayerSubscriptions();
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
  }

  /// Stops and reset
  Future<void> _stopAndReset() async {
    await _disposeCurrentPlayerOnly();
    _publishResetState();
  }

  /// Publish reset state
  void _publishResetState() {
    _currentMessageId = null;
    _lastActiveMessageId = null;
    if (!_activeIdController.isClosed) _activeIdController.add(null);

    _lastPlayerState = PlayerState(false, ProcessingState.idle);
    if (!_stateController.isClosed) _stateController.add(_lastPlayerState);

    _lastPosition = Duration.zero;
    if (!_positionController.isClosed) _positionController.add(Duration.zero);

    _lastDuration = Duration.zero;
    if (!_durationController.isClosed) _durationController.add(Duration.zero);
  }

  /// Apply speed
  Future<void> _applySpeed(AudioPlayer player) async {
    if (!identical(_player, player)) return;
    if (kIsWeb) {
      if (player.processingState != ProcessingState.ready) {
        await player.playerStateStream.firstWhere(
          (state) =>
              identical(_player, player) &&
              (state.processingState == ProcessingState.ready ||
                  state.processingState == ProcessingState.completed),
        );
      }
      if (!identical(_player, player)) return;
    }
    await player.setSpeed(_speed);
  }

  /// Configure session
  Future<void> _configureSession() async {
    if (_sessionConfigured || kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {}
    _sessionConfigured = true;
  }

  /// Releases controllers and subscriptions used by this widget
  Future<void> dispose() async {
    /// Run
    await _run(() async {
      await _stopAndReset();
      await _stateController.close();
      await _positionController.close();
      await _durationController.close();
      await _activeIdController.close();
    });
  }
}
