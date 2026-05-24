import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/feed/feed_post.dart';
import '../../models/feed/post_crop_transform.dart';
import '../../models/feed/post_media_source.dart';
import '../upload_service.dart';
import 'post_repository.dart';

class PostPublishService {
  PostPublishService({PostRepository? repository})
    : _repository = repository ?? PostRepository();

  static const _bucket = 'posts';
  static const _targetWidth = 1080;
  static const _targetHeight = 1920;

  final PostRepository _repository;
  final _client = Supabase.instance.client;

  Future<FeedPost> publish(
    PostDraft draft, {
    Uint8List? videoThumbnailBytes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const PostPublishException('Utilizador não autenticado.');
    }

    String? uploadedMediaUrl;
    String? uploadedThumbnailUrl;

    try {
      final mediaBytes = draft.source.isImage && !draft.crop.isBaked
          ? await _renderCroppedImage(draft)
          : await _resolveSourceBytes(draft.source);

      final mediaExt = draft.source.isImage
          ? '.jpg'
          : _extensionFromMime(draft.source.mimeType);
      final mediaMime = draft.source.isImage
          ? 'image/jpeg'
          : draft.source.mimeType;
      final mediaName = 'media/${const Uuid().v4()}$mediaExt';

      uploadedMediaUrl = (await UploadService.uploadFile(
        bucket: _bucket,
        fileName: mediaName,
        fileBytes: mediaBytes,
        mimeType: mediaMime,
      )).url;

      if (draft.source.isImage) {
        uploadedThumbnailUrl = uploadedMediaUrl;
      } else if (videoThumbnailBytes != null) {
        uploadedThumbnailUrl = (await UploadService.uploadFile(
          bucket: _bucket,
          fileName: 'thumbs/${const Uuid().v4()}.jpg',
          fileBytes: videoThumbnailBytes,
          mimeType: 'image/jpeg',
        )).url;
      }

      final finalCrop = draft.source.isImage
          ? draft.crop.clamped().copyWith(
              scale: 1.0,
              offsetX: 0.0,
              offsetY: 0.0,
              isBaked: true,
            )
          : draft.crop.clamped();

      return await _repository.insertPost(
        mediaUrl: uploadedMediaUrl,
        mediaType: draft.source.type.wireName,
        caption: draft.caption,
        thumbnailUrl: uploadedThumbnailUrl,
        crop: finalCrop.toJson(),
      );
    } catch (e) {
      await _cleanupUploaded(uploadedThumbnailUrl);
      await _cleanupUploaded(uploadedMediaUrl);
      if (e is PostPublishException) rethrow;
      throw PostPublishException('Erro ao publicar o post: $e');
    }
  }

  Future<Uint8List> _renderCroppedImage(PostDraft draft) async {
    final sourceBytes = await _resolveSourceBytes(draft.source);
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const PostPublishException('Imagem inválida.');
    }

    final cropRect = _sourceCropRect(decoded.width, decoded.height, draft.crop);
    final cropped = img.copyCrop(
      decoded,
      x: cropRect.x,
      y: cropRect.y,
      width: cropRect.width,
      height: cropRect.height,
    );

    // Maintain aspect ratio of the crop when resizing.
    // Use _targetWidth as the reference width.
    final targetW = _targetWidth;
    final targetH = (targetW * (cropped.height / cropped.width)).round();

    final resized = img.copyResize(
      cropped,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }

  _CropRect _sourceCropRect(
    int sourceWidth,
    int sourceHeight,
    PostCropTransform transform,
  ) {
    const targetAspect = _targetWidth / _targetHeight;
    final sourceAspect = sourceWidth / sourceHeight;

    double baseX = 0;
    double baseY = 0;
    double baseW = sourceWidth.toDouble();
    double baseH = sourceHeight.toDouble();

    if (sourceAspect > targetAspect) {
      baseW = sourceHeight * targetAspect;
      baseX = (sourceWidth - baseW) / 2;
    } else {
      baseH = sourceWidth / targetAspect;
      baseY = (sourceHeight - baseH) / 2;
    }

    final cropState = transform.clamped();

    // cw, ch are dimensions relative to the 9:16 frame
    final cw = cropState.cropRight - cropState.cropLeft;
    final ch = cropState.cropBottom - cropState.cropTop;
    final cropCenterX = (cropState.cropLeft + cropState.cropRight) / 2;
    final cropCenterY = (cropState.cropTop + cropState.cropBottom) / 2;

    // Viewport size in base 9:16 frame
    final viewportW = baseW * cw;
    final viewportH = baseH * ch;

    // Actual crop size on original image depends on scale (zoom)
    final cropW = viewportW / cropState.scale;
    final cropH = viewportH / cropState.scale;

    // Center in original image coordinates
    final centerX =
        baseX +
        baseW * cropCenterX -
        cropState.offsetX * (baseW / cropState.scale);
    final centerY =
        baseY +
        baseH * cropCenterY -
        cropState.offsetY * (baseH / cropState.scale);

    final x = (centerX - cropW / 2).round();
    final y = (centerY - cropH / 2).round();

    final safeX = x.clamp(0, sourceWidth - 1);
    final safeY = y.clamp(0, sourceHeight - 1);

    return _CropRect(
      x: safeX,
      y: safeY,
      width: cropW.round().clamp(1, sourceWidth - safeX),
      height: cropH.round().clamp(1, sourceHeight - safeY),
    );
  }

  Future<Uint8List> _resolveSourceBytes(PostMediaSource source) async {
    if (source.bytes != null) return source.bytes!;
    if (!kIsWeb && source.path != null && source.path!.isNotEmpty) {
      return File(source.path!).readAsBytes();
    }
    throw const PostPublishException('Não foi possível ler a media.');
  }

  Future<void> _cleanupUploaded(String? url) async {
    if (url == null || url.isEmpty) return;
    final marker = '/storage/v1/object/public/$_bucket/';
    final index = url.indexOf(marker);
    if (index == -1) return;
    final path = Uri.decodeFull(url.substring(index + marker.length));
    if (path.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove([path]);
    } catch (_) {}
  }

  String _extensionFromMime(String mime) {
    switch (mime) {
      case 'video/mp4':
        return '.mp4';
      case 'video/quicktime':
        return '.mov';
      case 'video/webm':
        return '.webm';
      default:
        return '.bin';
    }
  }
}

class _CropRect {
  const _CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

class PostPublishException implements Exception {
  const PostPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}
