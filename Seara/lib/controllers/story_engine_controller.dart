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
    required List<StoryUser> users,
    required this.feedController,
    required int initialUserIndex,
  }) : _userIndex = initialUserIndex,
       users = List.from(users) {
    _storyIndex = _findFirstUnseenIndex(currentUser);
  }

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

  bool _isReady = false;
  bool get isReady => _isReady;

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

  // ── Activate / preload ───────────────────────────────────────────────────

  Future<void> _activateStory(TickerProvider? vsync) async {
    if (_disposed) return;

    final story = currentStory;
    feedController.markSeen(story.id);

    // Clean up previous active player instance immediately.
    _activePlayer?.dispose();
    _activePlayer = null;

    if (story.isVideo) {
      // 1. Create a fresh player instance.
      final player = Player();
      _activePlayer = player;

      // 2. Notify listeners immediately so that the UI (StoryVideoPlayerWidget)
      // can build and attach the VideoController BEFORE the player opens and plays the media.
      notifyListeners();

      // 3. Configure and open the media.
      await player.setPlaylistMode(PlaylistMode.none);
      await player.setVolume(_isMuted ? 0 : 100);
      await player.open(Media(story.mediaUrl), play: !_isPaused);

      if (_disposed) return;

      // 4. Wait for actual duration.
      final duration = await _resolveDuration(story);
      if (_disposed) return;

      progressController.duration = Duration(
        milliseconds: (duration * 1000).toInt(),
      );
    } else {
      progressController.duration = Duration(
        milliseconds: (story.effectiveDuration * 1000).toInt(),
      );
    }

    progressController.reset();
    if (!_isPaused) progressController.forward();

    notifyListeners();
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

  void _preloadNext() {
    // Disabled background video preloading to guarantee completely stable video
    // texture bindings and avoid race conditions or background player conflicts.
    _nextPlayer?.dispose();
    _nextPlayer = null;
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
      _storyIndex = _findFirstUnseenIndex(currentUser);
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
      _activateStory(vsync);
    } else if (_userIndex > 0) {
      _userIndex--;
      _storyIndex = _findLastUnseenIndex(currentUser);
      _activateStory(vsync);
    } else {
      // Already at first story of first user, reset progress to 0.
      progressController.reset();
      _activePlayer?.seek(Duration.zero);
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
    _activePlayer?.dispose();
    _nextPlayer?.dispose();
    _activePlayer = null;
    _nextPlayer = null;
    super.dispose();
  }
}
