import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryManagementService {
  final _client = Supabase.instance.client;

  /// Fetches the profiles of users who viewed a specific story, ordered by viewed_at DESC.
  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      final response = await _client
          .from('story_views')
          .select('*, users:viewer_id(username, avatar_url:avatar)')
          .eq('story_id', storyId)
          .order('viewed_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);
      if (currentUserId != null) {
        list.removeWhere((item) => item['viewer_id'] == currentUserId);
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint(
        'StoryManagementService: Error fetching viewers: $e\n$stackTrace',
      );
      return [];
    }
  }

  /// Deletes a story's database records and its media file from storage.
  Future<void> deleteStory(String storyId, String mediaUrl) async {
    // 1. Delete story views (in case DB cascade isn't set up)
    try {
      await _client.from('story_views').delete().eq('story_id', storyId);
    } catch (e) {
      debugPrint('StoryManagementService: Warning deleting story_views: $e');
    }

    // 2. Delete story record
    await _client.from('stories').delete().eq('id', storyId);

    // 3. Delete media from Storage bucket
    try {
      final uri = Uri.parse(mediaUrl);
      final fileName = uri.pathSegments.last;
      await _client.storage.from('stories').remove([fileName]);
    } catch (e) {
      debugPrint('StoryManagementService: Warning deleting storage file: $e');
    }
  }
}
