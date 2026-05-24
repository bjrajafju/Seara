import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/feed/post_comment.dart';

class CommentRepository {
  CommentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PostComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('post_comments')
        .select('*, users:user_id(id, username, avatar_url:avatar)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return rows
        .map((row) => PostComment.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<PostComment> insertComment(String postId, String content) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const CommentRepositoryException('Utilizador não autenticado.');
    }

    final row = await _client
        .from('post_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'content': content.trim(),
        })
        .select('*, users:user_id(id, username, avatar_url:avatar)')
        .single();

    return PostComment.fromJson(Map<String, dynamic>.from(row));
  }
}

class CommentRepositoryException implements Exception {
  const CommentRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
