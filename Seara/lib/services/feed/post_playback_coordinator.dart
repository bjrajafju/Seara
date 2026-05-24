import 'dart:async';
import 'package:flutter/foundation.dart';

class PostPlaybackCoordinator extends ChangeNotifier {
  static final PostPlaybackCoordinator _instance =
      PostPlaybackCoordinator._internal();
  factory PostPlaybackCoordinator() => _instance;
  PostPlaybackCoordinator._internal();

  final Map<String, PostPlaybackMetrics> _visibleVideos = {};
  String? _activePostId;
  String? _pendingPostId;
  bool _isTransitioning = false;

  String? get activePostId => _activePostId;

  void reportVisibility(String postId, PostPlaybackMetrics metrics) {
    final wasVisible = _visibleVideos.containsKey(postId);
    if (metrics.visibleFraction <= 0) {
      _visibleVideos.remove(postId);
    } else {
      _visibleVideos[postId] = metrics;
    }

    if (wasVisible != _visibleVideos.containsKey(postId)) {
      notifyListeners();
    }
    _scheduleUpdate();
  }

  bool isVisible(String postId) => _visibleVideos.containsKey(postId);

  void unregister(String postId) {
    final wasRemoved = _visibleVideos.remove(postId) != null;
    if (_activePostId == postId || _pendingPostId == postId) {
      _pendingPostId = null;
      _scheduleUpdate();
    }
    if (wasRemoved) {
      notifyListeners();
    }
  }

  Timer? _updateTimer;
  void _scheduleUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 50), _updateActiveVideo);
  }

  void _updateActiveVideo() {
    if (_visibleVideos.isEmpty) {
      if (_activePostId != null || _pendingPostId != null) {
        _pendingPostId = null;
        if (!_isTransitioning) _runTransition();
      }
      return;
    }

    String? winnerId;
    double minDistance = double.infinity;

    _visibleVideos.forEach((postId, metrics) {
      if (metrics.visibleFraction < 0.4) return;

      double distance = metrics.distanceToCenter;

      // Bias toward currently active video to prevent flickering
      if (postId == _activePostId) {
        distance *= 0.8;
      }

      if (distance < minDistance) {
        minDistance = distance;
        winnerId = postId;
      }
    });

    if (winnerId != (_pendingPostId ?? _activePostId)) {
      _pendingPostId = winnerId;
      if (!_isTransitioning) {
        _runTransition();
      }
    }
  }

  Future<void> _runTransition() async {
    _isTransitioning = true;

    try {
      while (_pendingPostId != _activePostId) {
        final targetId = _pendingPostId;

        // 1. Pause old video by setting active to null
        _activePostId = null;
        notifyListeners();

        // 2. Wait one frame
        await Future.delayed(Duration.zero);

        // 3. Play new video
        _activePostId = targetId;
        notifyListeners();
      }
    } finally {
      _isTransitioning = false;
    }
  }
}

class PostPlaybackMetrics {
  final double visibleFraction;
  final double distanceToCenter;

  PostPlaybackMetrics({
    required this.visibleFraction,
    required this.distanceToCenter,
  });
}
