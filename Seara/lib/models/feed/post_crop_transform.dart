import 'dart:math' as math;

class PostCropTransform {
  const PostCropTransform({
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 1,
    this.cropBottom = 1,
    this.isBaked = false,
  });

  final double scale;
  final double offsetX;
  final double offsetY;

  /// Normalized crop frame coordinates in [0, 1].
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  /// Whether the media bytes are already cropped to the frame.
  final bool isBaked;

  static const identity = PostCropTransform();
  static const double maxScale = 4;

  double get cropWidth => cropRight - cropLeft;
  double get cropHeight => cropBottom - cropTop;

  PostCropTransform copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    bool? isBaked,
  }) {
    return PostCropTransform(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
      isBaked: isBaked ?? this.isBaked,
    );
  }

  PostCropTransform clamped() {
    final cl = cropLeft.clamp(0.0, 1.0);
    final ct = cropTop.clamp(0.0, 1.0);
    // Ensure minimum size
    final cr = math.max(cropRight, cl + 0.05).clamp(0.0, 1.0);
    final cb = math.max(cropBottom, ct + 0.05).clamp(0.0, 1.0);

    const minScale = 1.0;
    final safeScale = scale.clamp(minScale, maxScale);

    // Clamp offsets so media always covers the crop frame.
    // At scale s, media spans [(1-s)/2 + ox, (1+s)/2 + ox] in normalized X.
    // For media left <= cropLeft:  ox <= cl + (s-1)/2
    // For media right >= cropRight: ox >= cr - 1 - (s-1)/2
    final maxOX = cl + (safeScale - 1) / 2;
    final minOX = cr - 1 - (safeScale - 1) / 2;
    final maxOY = ct + (safeScale - 1) / 2;
    final minOY = cb - 1 - (safeScale - 1) / 2;

    return PostCropTransform(
      scale: safeScale,
      offsetX: offsetX.clamp(minOX, maxOX),
      offsetY: offsetY.clamp(minOY, maxOY),
      cropLeft: cl,
      cropTop: ct,
      cropRight: cr,
      cropBottom: cb,
      isBaked: isBaked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scale': scale,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'cropLeft': cropLeft,
      'cropTop': cropTop,
      'cropRight': cropRight,
      'cropBottom': cropBottom,
      'is_baked': isBaked,
    };
  }

  factory PostCropTransform.fromJson(Object? json) {
    if (json is! Map) return identity;
    return PostCropTransform(
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0,
      cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0,
      cropRight: (json['cropRight'] as num?)?.toDouble() ?? 1,
      cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 1,
      isBaked: json['is_baked'] as bool? ?? false,
    );
  }
}
