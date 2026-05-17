import 'feed_story.dart';

/// Aggregates a user's profile info with their list of active stories.
///
/// The [hasUnseen] flag drives the visual ring colour in [StoryBubble]
/// and the sort order in [StoriesRow] (unseen users appear first).
class StoryUser {
  final String userId;
  final String username;
  final String avatarUrl;

  /// Stories are pre-sorted oldest → newest so the viewer plays in order.
  final List<FeedStory> stories;

  /// IDs of stories that the current user has already seen.
  final Set<String> seenIds;

  const StoryUser({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.stories,
    required this.seenIds,
  });

  /// True if at least one story has not been seen yet.
  bool get hasUnseen => stories.any((s) => !seenIds.contains(s.id));

  /// Returns a copy with [storyId] added to the seen set.
  StoryUser markSeen(String storyId) {
    return StoryUser(
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      stories: stories,
      seenIds: {...seenIds, storyId},
    );
  }

  factory StoryUser.fromJson({
    required Map<String, dynamic> profileJson,
    required List<FeedStory> stories,
    required Set<String> seenIds,
  }) {
    return StoryUser(
      userId: profileJson['id'] as String,
      username: profileJson['username'] as String? ?? 'user',
      avatarUrl: profileJson['avatar_url'] as String? ??
          'https://ui-avatars.com/api/?name=${profileJson['username'] ?? 'U'}',
      stories: stories,
      seenIds: seenIds,
    );
  }
}
