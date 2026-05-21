import 'dart:typed_data';

import 'post_crop_transform.dart';

enum PostMediaType { image, video }

extension PostMediaTypeName on PostMediaType {
  String get wireName => this == PostMediaType.video ? 'video' : 'image';

  bool get isVideo => this == PostMediaType.video;
  bool get isImage => this == PostMediaType.image;
}

class PostMediaSource {
  const PostMediaSource({
    required this.type,
    required this.mimeType,
    required this.fileName,
    this.path,
    this.bytes,
    this.previewUrl,
  });

  final PostMediaType type;
  final String mimeType;
  final String fileName;
  final String? path;
  final Uint8List? bytes;
  final String? previewUrl;

  bool get isVideo => type.isVideo;
  bool get isImage => type.isImage;

  String get displaySource => previewUrl ?? path ?? '';
}

class PostDraft {
  const PostDraft({
    required this.source,
    required this.crop,
    this.caption = '',
  });

  final PostMediaSource source;
  final PostCropTransform crop;
  final String caption;

  PostDraft copyWith({
    PostMediaSource? source,
    PostCropTransform? crop,
    String? caption,
  }) {
    return PostDraft(
      source: source ?? this.source,
      crop: crop ?? this.crop,
      caption: caption ?? this.caption,
    );
  }
}
