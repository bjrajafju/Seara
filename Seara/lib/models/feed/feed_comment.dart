class FeedComment {
  final int id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  FeedComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory FeedComment.fromMap(Map<String, dynamic> map) {
    return FeedComment(
      id: map['id'] as int,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
