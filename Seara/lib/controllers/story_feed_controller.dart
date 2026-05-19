import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feed/story_user.dart';
import '../services/feed/story_repository.dart';

/// Data-layer only controller.
///
/// Responsibilities:
/// - Fetch and sort [StoryUser] list from [StoryRepository].
/// - Optimistically update seen state so [StoryBubble] turns grey
///   immediately when returning from the viewer — no extra round-trip.
///
/// This controller does NOT manage viewer navigation or playback.
/// That is the exclusive responsibility of [StoryEngineController].
class StoryFeedController extends ChangeNotifier {
  final _repo = StoryRepository();

  List<StoryUser> _users = [];
  bool _isLoading = false;
  String? _error;

  List<StoryUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches stories. Call on first mount and on pull-to-refresh.
  Future<void> fetch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _repo.fetchFeedUsers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks [storyId] as seen — optimistic local update + async Supabase write.
  /// Safely no-ops if the user is not authenticated.
  void markSeen(String storyId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Optimistic UI: update local state immediately.
    _users = _users.map((u) {
      if (u.stories.any((s) => s.id == storyId)) {
        return u.markSeen(storyId);
      }
      return u;
    }).toList();
    notifyListeners();

    // Fire-and-forget: persist to Supabase in the background.
    _repo.markAsSeen(storyId: storyId, viewerId: currentUserId);
  }

  /// Removes [storyId] from the local user list, updating the UI dynamically.
  void removeStory(String storyId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final List<StoryUser> updatedUsers = [];
    for (final u in _users) {
      final updatedStories = u.stories.where((s) => s.id != storyId).toList();
      if (updatedStories.isNotEmpty || u.userId == currentUserId) {
        updatedUsers.add(
          StoryUser(
            userId: u.userId,
            dbId: u.dbId,
            username: u.username,
            avatarUrl: u.avatarUrl,
            stories: updatedStories,
            seenIds: u.seenIds,
          ),
        );
      }
    }
    _users = updatedUsers;
    notifyListeners();
  }
}
