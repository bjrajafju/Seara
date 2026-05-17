import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../models/feed/feed_story.dart';
import '../models/feed/story_user.dart';
import '../services/feed/audio_preferences_service.dart';
import 'story_feed_controller.dart';

/// The SINGLE source of truth for all viewer state and navigation.
///
/// Manages:
/// - Which user is currently visible (user page index).
/// - Which story within that user is currently active (story index).
/// - Progress animation for the current story.
/// - Pause / resume lifecycle.
/// - Preload of next media (ACTIVE + NEXT only hold controllers).
/// - Global mute state.
/// - Signalling [StoryFeedController] when a story is seen.
///
/// Gesture layer and UI components signal INTENTS to this engine.
/// The engine decides what happens — no UI widget calls navigation directly.
class StoryEngineController extends ChangeNotifier {
  StoryEngineController({
    required this.users,
    required this.feedController,
    required int initialUserIndex,
  }) : _userIndex = initialUserIndex;

  final List<StoryUser> users;
  final StoryFeedController feedController;

  // ── Navigation state ─────────────────────────────────────────────────────
  int _userIndex;
  int _storyIndex = 0;

  int get userIndex => _userIndex;
  int get storyIndex => _storyIndex;

  StoryUser get currentUser => users[_userIndex];
  FeedStory get currentStory => currentUser.stories[_storyIndex];

  bool get isLastStoryOfLastUser =>
      _userIndex == users.length - 1 &&
      _storyIndex == currentUser.stories.length - 1;

  // ── Progress animation ───────────────────────────────────────────────────
  late AnimationController progressController;

  // ── Pause state ──────────────────────────────────────────────────────────
  bool _isPaused = false;
  bool get isPaused => _isPaused;

  // ── Mute state ───────────────────────────────────────────────────────────
  bool _isMuted = true;
  bool get isMuted => _isMuted;

  // ── Video controllers ────────────────────────────────────────────────────
  // RULE: Only ACTIVE (index N) and NEXT (index N+1) may hold a Player.
  Player? _activePlayer;
  Player? _nextPlayer;

  Player? get activePlayer => _activePlayer;

  bool _disposed = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init(TickerProvider vsync) async {
    _isMuted = await AudioPreferencesService.isMuted();
    _initProgressController(vsync);
    await _activateStory(vsync);
  }

  void _initProgressController(TickerProvider vsync) {
    progressController = AnimationController(vsync: vsync, value: 0);
    progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryFinished();
      }
    });
  }

  // ── Activate / preload ───────────────────────────────────────────────────

  Future<void> _activateStory(TickerProvider? vsync) async {
    if (_disposed) return;

    final story = currentStory;
    feedController.markSeen(story.id);

    // Move the pre-loaded next player into active position.
    _activePlayer?.dispose();
    _activePlayer = _nextPlayer;
    _nextPlayer = null;

    if (story.isVideo) {
      // If we didn't have a preloaded player, create one now.
      _activePlayer ??= await _buildPlayer(story.mediaUrl);
      _activePlayer?.setVolume(_isMuted ? 0 : 100);
      _activePlayer?.play();

      // Wait for actual duration from metadata (with timeout fallback).
      final duration = await _resolveDuration(story);
      if (_disposed) return;

      progressController.duration = Duration(milliseconds: (duration * 1000).toInt());
    } else {
      _activePlayer = null; // images don't need a player
      progressController.duration = Duration(milliseconds: (story.effectiveDuration * 1000).toInt());
    }

    progressController.reset();
    if (!_isPaused) progressController.forward();

    // Preload next story.
    _preloadNext();
    notifyListeners();
  }

  Future<Player?> _buildPlayer(String url) async {
    try {
      final player = Player();
      await player.open(Media(url), play: false);
      return player;
    } catch (_) {
      return null;
    }
  }

  /// Waits up to 500ms for the player to report a real duration.
  /// Falls back to [FeedStory.effectiveDuration] if not available.
  Future<double> _resolveDuration(FeedStory story) async {
    if (_activePlayer == null) return story.effectiveDuration;

    final completer = Completer<double>();
    StreamSubscription? sub;
    final timeout = Timer(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(story.effectiveDuration);
    });

    sub = _activePlayer!.stream.duration.listen((dur) {
      if (dur.inMilliseconds > 0 && !completer.isCompleted) {
        completer.complete(dur.inSeconds.toDouble());
      }
    });

    final result = await completer.future;
    timeout.cancel();
    await sub.cancel();
    return result;
  }

  void _preloadNext() async {
    _nextPlayer?.dispose();
    _nextPlayer = null;

    final nextStory = _getNextStory();
    if (nextStory != null && nextStory.isVideo) {
      _nextPlayer = await _buildPlayer(nextStory.mediaUrl);
    }
  }

  FeedStory? _getNextStory() {
    if (_storyIndex < currentUser.stories.length - 1) {
      return currentUser.stories[_storyIndex + 1];
    }
    if (_userIndex < users.length - 1) {
      return users[_userIndex + 1].stories.first;
    }
    return null;
  }

  // ── Story finished ───────────────────────────────────────────────────────

  void _onStoryFinished() => next();

  // ── Public intent API (called by gesture layer / UI) ─────────────────────

  /// Advance to the next story or user.
  void next({TickerProvider? vsync}) {
    if (_disposed) return;

    if (_storyIndex < currentUser.stories.length - 1) {
      _storyIndex++;
      _activateStory(vsync);
    } else if (_userIndex < users.length - 1) {
      _userIndex++;
      _storyIndex = 0;
      _activateStory(vsync);
    } else {
      // Last story of last user — signal close.
      _shouldClose = true;
      notifyListeners();
    }
  }

  /// Go back to the previous story or user.
  void previous({TickerProvider? vsync}) {
    if (_disposed) return;

    if (_storyIndex > 0) {
      _storyIndex--;
    } else if (_userIndex > 0) {
      _userIndex--;
      _storyIndex = currentUser.stories.length - 1;
    }
    _activateStory(vsync);
  }

  /// Called when the PageView has animated to a new user index externally.
  void onUserPageChanged(int newUserIndex, {TickerProvider? vsync}) {
    if (_disposed || newUserIndex == _userIndex) return;
    _userIndex = newUserIndex;
    _storyIndex = 0;
    _activateStory(vsync);
  }

  // ── Pause / resume ───────────────────────────────────────────────────────

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    progressController.stop();
    _activePlayer?.pause();
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    progressController.forward();
    _activePlayer?.play();
    notifyListeners();
  }

  // ── Mute ─────────────────────────────────────────────────────────────────

  void toggleMute() {
    _isMuted = !_isMuted;
    _activePlayer?.setVolume(_isMuted ? 0 : 100);
    AudioPreferencesService.setMuted(_isMuted);
    notifyListeners();
  }

  // ── Close signal ─────────────────────────────────────────────────────────

  bool _shouldClose = false;
  bool get shouldClose => _shouldClose;

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    progressController.dispose();
    _activePlayer?.dispose();
    _nextPlayer?.dispose();
    _activePlayer = null;
    _nextPlayer = null;
    super.dispose();
  }
}
