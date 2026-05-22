import 'package:flutter/foundation.dart';

import '../models/feed/feed_post.dart';
import '../services/feed/post_repository.dart';

class PostFeedController extends ChangeNotifier {
  PostFeedController({PostRepository? repository})
    : _repository = repository ?? PostRepository();

  final PostRepository _repository;
  final List<FeedPost> _posts = [];

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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts();
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
      final posts = await _repository.fetchPosts(before: _posts.last.createdAt);
      _posts.addAll(posts);
      _hasMore = posts.length >= 12;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
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

  void incrementCommentCount(String postId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    _posts[index] = post.copyWith(commentCount: post.commentCount + 1);
    notifyListeners();
  }
}
