import 'dart:async';

import 'package:flutter/material.dart';

import '../models/feed/feed_story.dart';
import '../models/feed/story_user.dart';
import '../services/feed/audio_preferences_service.dart';
import '../services/feed/story_preload_service.dart';
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
    required List<StoryUser> users,
    required this.feedController,
    required int initialUserIndex,
  }) : _userIndex = initialUserIndex,
       users = List.from(users) {
    _storyIndex = _findFirstUnseenIndex(currentUser);
  }

  final List<StoryUser> users;
  final StoryFeedController feedController;

  // Navigation state
  int _userIndex;
  int _storyIndex = 0;

  int get userIndex => _userIndex;
  int get storyIndex => _storyIndex;

  StoryUser get currentUser => users[_userIndex];
  FeedStory get currentStory => currentUser.stories[_storyIndex];

  bool get isLastStoryOfLastUser =>
      _userIndex == users.length - 1 &&
      _storyIndex == currentUser.stories.length - 1;

  // Progress animation
  late AnimationController progressController;

  bool _isReady = false;
  bool get isReady => _isReady;

  bool _mediaReady = false;
  bool get mediaReady => _mediaReady;

  // Pause state

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  // Mute state
  bool _isMuted = true;
  bool get isMuted => _isMuted;

  // Video controllers
  // RULE: Keep the active story and near neighbours warm only.
  final StoryPreloadService _preloadService = StoryPreloadService();
  StoryPreloadedVideo? _activeVideo;
  int _activationSerial = 0;

  StoryPreloadedVideo? get activeVideo => _activeVideo;

  bool _disposed = false;

  // Init

  void init(TickerProvider vsync) {
    _initProgressController(vsync);
    _loadMuteAndActivate(vsync);
  }

  Future<void> _loadMuteAndActivate(TickerProvider vsync) async {
    _isMuted = await AudioPreferencesService.isMuted();
    if (_disposed) return;
    await _activateStory(vsync);
    _isReady = true;
    notifyListeners();
  }

  void _initProgressController(TickerProvider vsync) {
    progressController = AnimationController(vsync: vsync, value: 0);
    progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryFinished();
      }
    });
  }

  // Activate / preload

  Future<void> _activateStory(TickerProvider? vsync) async {
    if (_disposed) return;

    final activationSerial = ++_activationSerial;
    final story = currentStory;

    _mediaReady = false;

    feedController.markSeen(story.id);

    final oldVideo = _activeVideo;
    _activeVideo = null;

    notifyListeners();

    if (oldVideo != null) {
      try {
        await oldVideo.player.pause();
      } catch (_) {}
    }

    _activeVideo = null;

    if (story.isVideo) {
      _activeVideo = await _preloadService.activateVideo(
        story,
        isMuted: _isMuted,
        shouldPlay: false, // importante: não deixar autoplay já
      );
      notifyListeners();

      if (_disposed || activationSerial != _activationSerial) return;

      try {
        await _activeVideo!.player.seek(Duration.zero);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}

      if (!_isPaused) {
        _activeVideo!.player.play();
      }

      final duration = await _resolveDuration(story);
      if (_disposed || activationSerial != _activationSerial) return;

      progressController.duration = Duration(
        milliseconds: (duration * 1000).toInt(),
      );

      _mediaReady = false;
    } else {
      progressController.duration = Duration(
        milliseconds: (story.effectiveDuration * 1000).toInt(),
      );

      _mediaReady = true;
    }

    progressController.reset();

    if (!story.isVideo && !_isPaused) {
      progressController.forward();
    }

    _preloadService.preloadAround(
      users: users,
      userIndex: _userIndex,
      storyIndex: _storyIndex,
    );

    notifyListeners();
  }

  Future<void> ensureActiveVideoPlayback(StoryPreloadedVideo video) async {
    if (_disposed || _isPaused || _activeVideo != video) return;
    await video.ensurePlayingAfterAttach();
    if (_disposed || _isPaused || _activeVideo != video) return;
    _mediaReady = true;

    if (!progressController.isAnimating && !_isPaused) {
      progressController.forward();
    }

    notifyListeners();
  }

  void onVideoFirstFrameReady() {
    if (_disposed) return;

    _mediaReady = true;

    progressController
      ..reset()
      ..forward();

    notifyListeners();
  }

  /// Waits up to 500ms for the player to report a real duration.
  /// Falls back to [FeedStory.effectiveDuration] if not available.
  Future<double> _resolveDuration(FeedStory story) async {
    if (_activeVideo == null) return story.effectiveDuration;

    final cachedDuration = _activeVideo!.player.state.duration;
    if (cachedDuration.inMilliseconds > 0) {
      return cachedDuration.inSeconds.toDouble();
    }

    final completer = Completer<double>();
    StreamSubscription? sub;
    final timeout = Timer(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(story.effectiveDuration);
    });

    sub = _activeVideo!.player.stream.duration.listen((dur) {
      if (dur.inMilliseconds > 0 && !completer.isCompleted) {
        completer.complete(dur.inSeconds.toDouble());
      }
    });

    final result = await completer.future;
    timeout.cancel();
    await sub.cancel();
    return result;
  }

  // Story finished

  void _onStoryFinished() => next();

  // Public intent API (called by gesture layer / UI)

  /// Advance to the next story or user.
  void next({TickerProvider? vsync}) {
    if (_disposed) return;

    if (_storyIndex < currentUser.stories.length - 1) {
      _storyIndex++;
      _activateStory(vsync);
    } else if (_userIndex < users.length - 1) {
      _userIndex++;
      _storyIndex = _findFirstUnseenIndex(currentUser);
      _activateStory(vsync);
    } else {
      // Last story of last user - signal close.
      _shouldClose = true;
      notifyListeners();
    }
  }

  /// Go back to the previous story or user.
  void previous({TickerProvider? vsync}) {
    if (_disposed) return;

    if (_storyIndex > 0) {
      _storyIndex--;
      _activateStory(vsync);
    } else if (_userIndex > 0) {
      _userIndex--;
      _storyIndex = _findLastUnseenIndex(currentUser);
      _activateStory(vsync);
    } else {
      // Already at first story of first user, reset progress to 0.
      progressController.reset();
      _activeVideo?.player.seek(Duration.zero);
      if (!_isPaused) progressController.forward();
    }
  }

  /// Called when the PageView has animated to a new user index externally.
  void onUserPageChanged(int newUserIndex, {TickerProvider? vsync}) {
    if (_disposed || newUserIndex == _userIndex) return;
    final goingBack = newUserIndex < _userIndex;
    _userIndex = newUserIndex;
    if (goingBack) {
      _storyIndex = _findLastUnseenIndex(currentUser);
    } else {
      _storyIndex = _findFirstUnseenIndex(currentUser);
    }
    _activateStory(vsync);
  }

  // Pause / resume

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    progressController.stop();
    _activeVideo?.player.pause();
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    if (_mediaReady) {
      progressController.forward();
    }
    _activeVideo?.player.play();
    notifyListeners();
  }

  // Mute

  void toggleMute() {
    _isMuted = !_isMuted;
    _activeVideo?.player.setVolume(_isMuted ? 0 : 100);
    AudioPreferencesService.setMuted(_isMuted);
    notifyListeners();
  }

  // Close signal

  bool _shouldClose = false;
  bool get shouldClose => _shouldClose;

  // Dispose

  int _findFirstUnseenIndex(StoryUser user) {
    for (int i = 0; i < user.stories.length; i++) {
      if (!user.seenIds.contains(user.stories[i].id)) {
        return i;
      }
    }
    return 0; // Fallback: all stories are seen, start at oldest (index 0)
  }

  int _findLastUnseenIndex(StoryUser user) {
    for (int i = user.stories.length - 1; i >= 0; i--) {
      if (!user.seenIds.contains(user.stories[i].id)) {
        return i;
      }
    }
    return user.stories.length -
        1; // Fallback: all stories are seen, start at last story (index length - 1)
  }

  /// Handles navigation transitions after a story is successfully deleted.
  Future<void> handleStoryDeleted(String storyId) async {
    if (_disposed) return;

    // 1. Call feedController to remove it from memory
    feedController.removeStory(storyId);

    // 2. Remove story from our local engine user stories list
    final updatedStories = currentUser.stories
        .where((s) => s.id != storyId)
        .toList();

    if (updatedStories.isNotEmpty) {
      // User still has other stories!
      final updatedUser = StoryUser(
        userId: currentUser.userId,
        dbId: currentUser.dbId,
        username: currentUser.username,
        avatarUrl: currentUser.avatarUrl,
        stories: updatedStories,
        seenIds: currentUser.seenIds,
      );
      users[_userIndex] = updatedUser;

      // Clamp the story index if we were on the last one
      if (_storyIndex >= updatedStories.length) {
        _storyIndex = updatedStories.length - 1;
      }

      // Re-activate story playback
      await _activateStory(null);
    } else {
      // User has no stories left!
      users.removeAt(_userIndex);

      if (users.isEmpty) {
        // No users left in viewer, trigger close transition
        _shouldClose = true;
        notifyListeners();
      } else {
        // Transition to next user
        if (_userIndex >= users.length) {
          _userIndex = users.length - 1;
        }
        _storyIndex = _findFirstUnseenIndex(currentUser);
        await _activateStory(null);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    progressController.dispose();
    _preloadService.dispose();
    _activeVideo = null;
    super.dispose();
  }
}
