/// A single story item as returned by the Supabase backend.
class FeedStory {
  final String id;
  final String userId;
  final String mediaUrl;

  /// 'image' or 'video'
  final String type;

  /// Duration in seconds. For images this defaults to 6.0.
  final double duration;

  final DateTime createdAt;
  final DateTime expiresAt;

  const FeedStory({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.type,
    required this.duration,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';

  /// Effective playback duration.
  /// Falls back to 6s for images or when duration is invalid/zero.
  double get effectiveDuration {
    if (isImage) return 6.0;
    if (duration <= 0) return 15.0; // safety fallback for videos
    return duration.clamp(0.5, 60.0);
  }

  factory FeedStory.fromJson(Map<String, dynamic> json) {
    return FeedStory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaUrl: json['media_url'] as String,
      type: json['type'] as String,
      duration: (json['duration'] as num?)?.toDouble() ?? 6.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
