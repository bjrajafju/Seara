import 'post_crop_transform.dart';
import 'post_media_source.dart';

class FeedPost {
  const FeedPost({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.crop,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    required this.avatarUrl,
    this.caption,
    this.thumbnailUrl,
  });

  final String id;
  final String userId;
  final String mediaUrl;
  final PostMediaType mediaType;
  final String? caption;
  final String? thumbnailUrl;
  final PostCropTransform crop;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String username;
  final String avatarUrl;

  bool get isVideo => mediaType.isVideo;
  bool get isImage => mediaType.isImage;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    final username = user?['username'] as String? ?? 'user';
    return FeedPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
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
      avatarUrl:
          user?['avatar_url'] as String? ??
          user?['avatar'] as String? ??
          'https://ui-avatars.com/api/?name=$username',
    );
  }
}
