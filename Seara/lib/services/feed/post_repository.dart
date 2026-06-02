import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/feed/feed_post.dart';

class PostRepository {
  PostRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchPosts({
    int limit = 12,
    DateTime? before,
    List<String>? allowedUserIds,
  }) async {
    var query = _client
        .from('posts')
        .select(
          '*, users:user_id(id, username, avatar_url:avatar), post_likes(user_id), post_comments(id)',
        );

    if (allowedUserIds != null) {
      if (allowedUserIds.isEmpty) {
        // Se a lista estiver vazia (e.g. não logado), forçamos um filtro que não retorne nada
        query = query.eq('user_id', '00000000-0000-0000-0000-000000000000');
      } else if (allowedUserIds.length == 1) {
        query = query.eq('user_id', allowedUserIds.first);
      } else {
        query = query.inFilter('user_id', allowedUserIds);
      }
    }

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final currentUserId = _client.auth.currentUser?.id;
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows
        .map(
          (row) =>
              FeedPost.fromJson(Map<String, dynamic>.from(row), currentUserId),
        )
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
        .select(
          '*, users:user_id(id, username, avatar_url:avatar), post_likes(user_id), post_comments(id)',
        )
        .single();

    return FeedPost.fromJson(Map<String, dynamic>.from(row), userId);
  }

  Future<void> toggleLike(String postId, bool liked) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const PostRepositoryException('Utilizador não autenticado.');
    }

    if (liked) {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    } else {
      await _client.from('post_likes').delete().match({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<void> deletePost(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const PostRepositoryException('Utilizador não autenticado.');
    }

    // A regra de segurança do Supabase deve impedir o delete se o user_id não bater,
    // mas o match garante que o comando seja preciso.
    await _client.from('posts').delete().match({
      'id': postId,
      'user_id': userId,
    });
  }

  Future<List<String>> getFollowingAuthIds(int myBigIntId) async {
    final response = await _client
        .from('followers')
        .select('users:user_id(auth_id)')
        .eq('follower_id', myBigIntId);

    final List<String> ids = [];
    for (var row in response as List) {
      final authId = row['users']?['auth_id'];
      if (authId != null) ids.add(authId as String);
    }
    return ids;
  }
}

class PostRepositoryException implements Exception {
  const PostRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
