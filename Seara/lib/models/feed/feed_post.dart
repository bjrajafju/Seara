import 'post_crop_transform.dart';
import 'post_media_source.dart';

class FeedPost {
  const FeedPost({
    required this.id,
    required this.userId,
    this.userDbId,
    required this.mediaUrl,
    required this.mediaType,
    required this.crop,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    required this.avatarUrl,
    this.caption,
    this.thumbnailUrl,
    this.likeCount = 0,
    this.isLiked = false,
    this.commentCount = 0,
  });

  final String id;
  final String userId;
  final int? userDbId;
  final String mediaUrl;
  final PostMediaType mediaType;
  final String? caption;
  final String? thumbnailUrl;
  final PostCropTransform crop;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String username;
  final String avatarUrl;
  final int likeCount;
  final bool isLiked;
  final int commentCount;

  bool get isVideo => mediaType.isVideo;
  bool get isImage => mediaType.isImage;

  FeedPost copyWith({
    String? id,
    String? userId,
    int? userDbId,
    String? mediaUrl,
    PostMediaType? mediaType,
    String? caption,
    String? thumbnailUrl,
    PostCropTransform? crop,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? avatarUrl,
    int? likeCount,
    bool? isLiked,
    int? commentCount,
  }) {
    return FeedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDbId: userDbId ?? this.userDbId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      crop: crop ?? this.crop,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  factory FeedPost.fromJson(Map<String, dynamic> json, [String? currentUserId]) {
    final user = json['users'] as Map<String, dynamic>?;
    final username = user?['username'] as String? ?? 'user';

    final likesList = json['post_likes'] as List<dynamic>? ?? [];
    final commentsList = json['post_comments'] as List<dynamic>? ?? [];

    final isLiked = currentUserId != null &&
        likesList.any((like) => like['user_id'] == currentUserId);
    final likeCount = likesList.length;
    final commentCount = commentsList.length;

    return FeedPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userDbId: user?['id'] as int?,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] == 'video'
          ? PostMediaType.video
          : PostMediaType.image,
      caption: json['caption'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      crop: PostCropTransform.fromJson(json['crop']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      username: username,
      avatarUrl: user?['avatar_url'] as String? ??
          user?['avatar'] as String? ??
          'https://ui-avatars.com/api/?name=$username',
      likeCount: likeCount,
      isLiked: isLiked,
      commentCount: commentCount,
    );
  }
}
