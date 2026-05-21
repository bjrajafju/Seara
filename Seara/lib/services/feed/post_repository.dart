import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/feed/feed_post.dart';

class PostRepository {
  PostRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchPosts({int limit = 12, DateTime? before}) async {
    var query = _client
        .from('posts')
        .select('*, users:user_id(username, avatar_url:avatar)');

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows
        .map((row) => FeedPost.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<FeedPost> insertPost({
    required String mediaUrl,
    required String mediaType,
    required String? caption,
    required String? thumbnailUrl,
    required Map<String, dynamic> crop,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const PostRepositoryException('Utilizador não autenticado.');
    }

    final row = await _client
        .from('posts')
        .insert({
          'user_id': userId,
          'media_url': mediaUrl,
          'media_type': mediaType,
          'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
          'thumbnail_url': thumbnailUrl,
          'crop': crop,
        })
        .select('*, users:user_id(username, avatar_url:avatar)')
        .single();

    return FeedPost.fromJson(Map<String, dynamic>.from(row));
  }
}

class PostRepositoryException implements Exception {
  const PostRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
