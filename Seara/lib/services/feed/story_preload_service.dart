import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/feed/feed_story.dart';
import '../../models/feed/story_user.dart';

enum StoryPreloadPriority { high, medium, low }

/// Keeps a small warm pool of story video controllers.
///
/// The important bit is not only opening the URL. Each preloaded video creates
/// its [VideoController], briefly plays muted, then pauses so the decoder and
/// texture have a frame ready before the viewer needs it.
class StoryPreloadService {
  factory StoryPreloadService() => instance;

  StoryPreloadService._();

  static final StoryPreloadService instance = StoryPreloadService._();

  static const int _maxCachedVideos = 4;
  static const Duration _warmUpDelay = Duration(milliseconds: 100);
  static const Duration _firstFrameTimeout = Duration(milliseconds: 450);

  final LinkedHashMap<String, StoryPreloadedVideo> _videos =
      LinkedHashMap<String, StoryPreloadedVideo>();

  StoryPreloadedVideo? getVideo(String storyId) => _videos[storyId];

  Future<StoryPreloadedVideo?> activateVideo(
    FeedStory story, {
    required bool isMuted,
    required bool shouldPlay,
  }) async {
    if (!story.isVideo) return null;

    final video = await preloadVideo(
      story,
      priority: StoryPreloadPriority.high,
    );
    if (video == null || video.isDisposed) return null;

    await video.warmUp();
    if (video.isDisposed) return null;

    await video.player.setVolume(isMuted ? 0 : 100);
    await video.restartPlayback(shouldPlay: shouldPlay);
    _touch(story.id);
    return video;
  }

  Future<StoryPreloadedVideo?> preloadVideo(
    FeedStory story, {
    required StoryPreloadPriority priority,
  }) async {
    if (!story.isVideo) return null;

    final cached = _videos[story.id];
    if (cached != null && !cached.isDisposed) {
      _touch(story.id);
      return cached;
    }

    final video = StoryPreloadedVideo._(story);
    _videos[story.id] = video;
    _trimOverflow(retainIds: _videos.keys.toSet());

    unawaited(video.warmUp());
    return video;
  }

  void preloadAround({
    required List<StoryUser> users,
    required int userIndex,
    required int storyIndex,
  }) {
    final targets = _preloadTargets(
      users: users,
      userIndex: userIndex,
      storyIndex: storyIndex,
    );

    for (final target in targets) {
      unawaited(preloadVideo(target.story, priority: target.priority));
    }

    final retainIds = targets.map((target) => target.story.id).toSet()
      ..add(users[userIndex].stories[storyIndex].id);
    _disposeOutside(retainIds);
    _trimOverflow(retainIds: retainIds);
  }

  List<_PreloadTarget> _preloadTargets({
    required List<StoryUser> users,
    required int userIndex,
    required int storyIndex,
  }) {
    final currentUser = users[userIndex];
    final targets = <_PreloadTarget>[];

    if (storyIndex < currentUser.stories.length - 1) {
      targets.add(
        _PreloadTarget(
          currentUser.stories[storyIndex + 1],
          StoryPreloadPriority.high,
        ),
      );
    }

    if (userIndex < users.length - 1 &&
        users[userIndex + 1].stories.isNotEmpty) {
      targets.add(
        _PreloadTarget(
          users[userIndex + 1].stories.first,
          StoryPreloadPriority.medium,
        ),
      );
    }

    final previous = _previousStory(users, userIndex, storyIndex);
    if (previous != null) {
      targets.add(_PreloadTarget(previous, StoryPreloadPriority.low));
    }

    return targets.where((target) => target.story.isVideo).toList();
  }

  FeedStory? _previousStory(
    List<StoryUser> users,
    int userIndex,
    int storyIndex,
  ) {
    if (storyIndex > 0) {
      return users[userIndex].stories[storyIndex - 1];
    }
    if (userIndex > 0 && users[userIndex - 1].stories.isNotEmpty) {
      return users[userIndex - 1].stories.last;
    }
    return null;
  }

  void _touch(String storyId) {
    final video = _videos.remove(storyId);
    if (video != null) {
      _videos[storyId] = video;
    }
  }

  void _disposeOutside(Set<String> retainIds) {
    final disposableIds = _videos.keys
        .where((storyId) => !retainIds.contains(storyId))
        .toList();
    for (final storyId in disposableIds) {
      _videos.remove(storyId)?.dispose();
    }
  }

  void _trimOverflow({required Set<String> retainIds}) {
    while (_videos.length > _maxCachedVideos) {
      final firstKey = _videos.keys.first;
      if (retainIds.contains(firstKey)) {
        _touch(firstKey);
        if (_videos.keys.every(retainIds.contains)) return;
        continue;
      }
      _videos.remove(firstKey)?.dispose();
    }
  }

  void dispose() {
    for (final video in _videos.values) {
      video.dispose();
    }
    _videos.clear();
  }
}

class StoryPreloadedVideo {
  StoryPreloadedVideo._(this.story) : player = Player() {
    controller = VideoController(player);
  }

  final FeedStory story;
  final Player player;
  late final VideoController controller;

  bool _isDisposed = false;
  bool _hasWarmed = false;
  Future<void>? _warmUpFuture;
  bool _firstFrameReady = false;
  Completer<void>? _firstFrameCompleter;

  bool get isDisposed => _isDisposed;
  bool get isFirstFrameReady => _firstFrameReady;

  Future<void> get firstFrameReady {
    if (_firstFrameReady) return Future<void>.value();
    return (_firstFrameCompleter ??= Completer<void>()).future;
  }

  Future<void> warmUp() async {
    if (_isDisposed || _hasWarmed) return;
    return _warmUpFuture ??= _runWarmUp();
  }

  Future<void> _runWarmUp() async {
    try {
      await player.setPlaylistMode(PlaylistMode.none);
      await player.setVolume(0);
      await player.open(Media(story.mediaUrl), play: false);
      if (_isDisposed) return;

      await player.play();
      await Future.any<void>([
        controller.waitUntilFirstFrameRendered.then(
          (_) => _markFirstFrameReady(),
        ),
        Future<void>.delayed(StoryPreloadService._warmUpDelay),
      ]);
      if (_isDisposed) return;

      await player.pause();
      await controller.waitUntilFirstFrameRendered
          .timeout(StoryPreloadService._firstFrameTimeout)
          .then((_) => _markFirstFrameReady())
          .catchError((Object error) {
            debugPrint(
              'StoryPreloadService: first frame timeout for ${story.id}',
            );
          });
      _hasWarmed = true;
    } catch (error, stackTrace) {
      debugPrint('StoryPreloadService: warm-up failed for ${story.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      dispose();
    } finally {
      if (!_hasWarmed) {
        _warmUpFuture = null;
      }
    }
  }

  void markFirstFrameReady() => _markFirstFrameReady();

  Future<void> restartPlayback({required bool shouldPlay}) async {
    if (_isDisposed) return;

    final state = player.state;
    if (state.completed || _isNearEnd(state.position, state.duration)) {
      await player.open(Media(story.mediaUrl), play: shouldPlay);
      return;
    }

    await player.seek(Duration.zero);
    if (shouldPlay) {
      await player.play();
    } else {
      await player.pause();
    }
  }

  Future<void> ensurePlayingAfterAttach() async {
    if (_isDisposed) return;

    final state = player.state;
    if (state.completed || _isNearEnd(state.position, state.duration)) {
      await player.seek(Duration.zero);
    }

    if (!player.state.playing) {
      await player.play();
    }

    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!_isDisposed && !player.state.playing) {
        await player.play();
      }
    }
  }

  bool _isNearEnd(Duration position, Duration duration) {
    return position.inMilliseconds > 0 &&
        duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 150;
  }

  void _markFirstFrameReady() {
    if (_firstFrameReady) return;
    _firstFrameReady = true;
    _firstFrameCompleter?.complete();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    player.dispose();
    if (_firstFrameCompleter != null && !_firstFrameCompleter!.isCompleted) {
      _firstFrameCompleter!.complete();
    }
  }
}

class _PreloadTarget {
  const _PreloadTarget(this.story, this.priority);

  final FeedStory story;
  final StoryPreloadPriority priority;
}
