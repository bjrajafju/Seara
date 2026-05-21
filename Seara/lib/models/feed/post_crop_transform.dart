import 'dart:math' as math;

class PostCropTransform {
  const PostCropTransform({this.scale = 1, this.offsetX = 0, this.offsetY = 0});

  final double scale;
  final double offsetX;
  final double offsetY;

  static const identity = PostCropTransform();
  static const double minScale = 1;
  static const double maxScale = 3;

  PostCropTransform copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
  }) {
    return PostCropTransform(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  PostCropTransform clamped() {
    final safeScale = scale.clamp(minScale, maxScale).toDouble();
    final maxX = math.max(0.0, (safeScale - 1) / 2);
    final maxY = math.max(0.0, (safeScale - 1) / 2);
    return PostCropTransform(
      scale: safeScale,
      offsetX: offsetX.clamp(-maxX, maxX).toDouble(),
      offsetY: offsetY.clamp(-maxY, maxY).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'scale': scale, 'offsetX': offsetX, 'offsetY': offsetY};
  }

  factory PostCropTransform.fromJson(Object? json) {
    if (json is! Map) return identity;
    return PostCropTransform(
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
    );
  }
}
