import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feed/feed_post.dart';
import '../services/auth_service.dart';
import '../services/feed/post_repository.dart';

class PostFeedController extends ChangeNotifier {
  PostFeedController({PostRepository? repository, String? targetAuthId})
    : _repository = repository ?? PostRepository(),
      _targetAuthId = targetAuthId {
    if (_targetAuthId == null) {
      _setupFollowSubscription();
    } else {
      _allowedUserIds = [_targetAuthId!];
    }
  }

  final PostRepository _repository;
  final String? _targetAuthId;
  final List<FeedPost> _posts = [];
  List<String> _allowedUserIds = [];
  StreamSubscription? _followSubscription;
  int? _currentSubscribedUserId;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  List<FeedPost> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> fetch({bool refresh = false}) async {
    if (_isLoading) return;

    if (_targetAuthId == null && _followSubscription == null) {
      _setupFollowSubscription();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_targetAuthId == null && (refresh || _allowedUserIds.isEmpty)) {
        await _refreshAllowedUsers();
      }

      final posts = await _repository.fetchPosts(
        allowedUserIds: _allowedUserIds,
      );
      _posts
        ..clear()
        ..addAll(posts);
      _hasMore = posts.length >= 12;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore || _posts.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        before: _posts.last.createdAt,
        allowedUserIds: _allowedUserIds,
      );
      _posts.addAll(posts);
      _hasMore = posts.length >= 12;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _refreshAllowedUsers() async {
    final currentAuthId = Supabase.instance.client.auth.currentUser?.id;
    if (currentAuthId == null) {
      _allowedUserIds = [];
      return;
    }

    final myBigIntId = await AuthService.getUserId();
    if (myBigIntId == null) {
      _allowedUserIds = [currentAuthId];
      return;
    }

    try {
      final following = await _repository.getFollowingAuthIds(myBigIntId);
      _allowedUserIds = [currentAuthId, ...following];
    } catch (e) {
      debugPrint('Error refreshing allowed users: $e');
      _allowedUserIds = [currentAuthId];
    }
  }

  void _setupFollowSubscription() async {
    final myBigIntId = await AuthService.getUserId();

    if (myBigIntId == _currentSubscribedUserId && _followSubscription != null) {
      return;
    }

    await _followSubscription?.cancel();
    _currentSubscribedUserId = myBigIntId;

    if (myBigIntId == null) {
      _followSubscription = null;
      return;
    }

    _followSubscription = Supabase.instance.client
        .from('followers')
        .stream(primaryKey: ['id'])
        .eq('follower_id', myBigIntId)
        .listen((_) async {
          await _refreshAllowedUsers();
          // Silently refresh the feed when social graph changes
          fetch(refresh: true);
        });
  }

  void insertAtTop(FeedPost post) {
    _posts.removeWhere((existing) => existing.id == post.id);
    _posts.insert(0, post);
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final wasLiked = post.isLiked;
    final newLikeCount = wasLiked ? post.likeCount - 1 : post.likeCount + 1;
    final updatedPost = post.copyWith(
      isLiked: !wasLiked,
      likeCount: newLikeCount < 0 ? 0 : newLikeCount,
    );

    // Optimistic update
    _posts[index] = updatedPost;
    notifyListeners();

    try {
      await _repository.toggleLike(postId, !wasLiked);
    } catch (e) {
      // Revert on error
      final revertIndex = _posts.indexWhere((p) => p.id == postId);
      if (revertIndex != -1) {
        _posts[revertIndex] = post;
        notifyListeners();
      }
    }
  }

  Future<void> deletePost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];

    // Optimistic update
    _posts.removeAt(index);
    notifyListeners();

    try {
      await _repository.deletePost(postId);
    } catch (e) {
      // Revert on error if the post was not already removed/replaced
      if (!_posts.any((p) => p.id == postId)) {
        _posts.insert(index < _posts.length ? index : _posts.length, post);
        notifyListeners();
      }
      rethrow;
    }
  }

  void incrementCommentCount(String postId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    _posts[index] = post.copyWith(commentCount: post.commentCount + 1);
    notifyListeners();
  }

  @override
  void dispose() {
    _followSubscription?.cancel();
    super.dispose();
  }
}
