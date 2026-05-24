class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    this.userDbId,
    required this.content,
    required this.createdAt,
    required this.username,
    required this.avatarUrl,
  });

  final int id;
  final String postId;
  final String userId;
  final int? userDbId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String avatarUrl;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    final username = user?['username'] as String? ?? 'user';
    return PostComment(
      id: json['id'] as int,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      userDbId: user?['id'] as int?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: username,
      avatarUrl: user?['avatar_url'] as String? ??
          user?['avatar'] as String? ??
          'https://ui-avatars.com/api/?name=$username',
    );
  }
}
