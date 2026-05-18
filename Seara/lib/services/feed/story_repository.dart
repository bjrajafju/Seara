import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/feed/feed_story.dart';
import '../../models/feed/story_user.dart';

/// Handles all Supabase queries related to the Stories feed.
///
/// Responsibilities:
/// - Fetch active (non-expired) stories grouped by user.
/// - Fetch which stories the current user has already seen.
/// - Record a view event when a story becomes visible.
class StoryRepository {
  final _client = Supabase.instance.client;

  /// Fetches all active stories (not expired) along with the author's
  /// profile, grouped into [StoryUser] objects.
  ///
  /// Returns users sorted: unseen first (chronologically), seen last.
  Future<List<StoryUser>> fetchFeedUsers() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // 1. Fetch non-expired stories with author profile data.
    final storiesResponse = await _client
        .from('stories')
        .select('*, users:user_id(id:auth_id, username, avatar_url:avatar)')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: true);

    if (storiesResponse.isEmpty) return [];

    // 2. Fetch which story IDs the current user has already seen.
    final viewsResponse = await _client
        .from('story_views')
        .select('story_id')
        .eq('viewer_id', currentUserId);

    final seenStoryIds = <String>{
      for (final row in viewsResponse) row['story_id'] as String,
    };

    // 3. Group stories by user_id.
    final Map<String, List<FeedStory>> byUser = {};
    final Map<String, Map<String, dynamic>> profiles = {};

    for (final row in storiesResponse) {
      final story = FeedStory.fromJson(row);
      final profile = row['users'] as Map<String, dynamic>;
      byUser.putIfAbsent(story.userId, () => []).add(story);
      profiles[story.userId] = profile;
    }

    // 4. Build StoryUser list.
    final users = byUser.entries.map((entry) {
      return StoryUser.fromJson(
        profileJson: profiles[entry.key]!,
        stories: entry.value,
        seenIds: seenStoryIds,
      );
    }).toList();

    // 5. Sort: own user first, then unseen first, then seen — each group chronologically.
    users.sort((a, b) {
      if (a.userId == currentUserId) return -1;
      if (b.userId == currentUserId) return 1;

      if (a.hasUnseen && !b.hasUnseen) return -1;
      if (!a.hasUnseen && b.hasUnseen) return 1;
      // Within same group, sort by oldest story first.
      return a.stories.first.createdAt.compareTo(b.stories.first.createdAt);
    });

    return users;
  }

  /// Records that [viewerId] has seen [storyId].
  /// Uses upsert with conflict resolution to avoid duplicate rows.
  Future<void> markAsSeen({
    required String storyId,
    required String viewerId,
  }) async {
    await _client.from('story_views').upsert({
      'story_id': storyId,
      'viewer_id': viewerId,
      'viewed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'story_id,viewer_id');
  }
}
