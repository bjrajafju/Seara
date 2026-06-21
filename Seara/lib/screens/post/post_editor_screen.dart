import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../controllers/post_feed_controller.dart';
import '../../models/feed/post_crop_transform.dart';
import '../../models/feed/post_media_source.dart';
import '../../services/feed/post_publish_service.dart';
import '../../widgets/feed/posts/post_media_frame.dart';

//
// Screen
//

class PostEditorScreen extends StatefulWidget {
  const PostEditorScreen({super.key, required this.source});

  final PostMediaSource source;

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  final _publishService = PostPublishService();
  final _captionController = TextEditingController();
  final _previewKey = GlobalKey();
  final _exportKey = GlobalKey();

  // crop state
  PostCropTransform _crop = PostCropTransform.identity;

  // gesture tracking
  PostCropTransform _gestureStartCrop = PostCropTransform.identity;
  Offset _gestureFocalStart = Offset.zero;

  // publish state
  PostDraft? _frozenDraft;
  bool _isPublishing = false;

  //
  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool get _isPreview => _frozenDraft != null;

  // navigation
  void _next() {
    setState(() {
      _frozenDraft = PostDraft(
        source: widget.source,
        crop: _crop.clamped(),
        caption: _captionController.text,
      );
    });
  }

  void _backToEdit() {
    setState(() {
      _crop = _frozenDraft?.crop ?? _crop;
      _frozenDraft = null;
    });
  }

  // zoom buttons
  void _zoomBy(double delta) {
    setState(() {
      _crop = _crop
          .copyWith(
            scale: (_crop.scale + delta).clamp(1.0, PostCropTransform.maxScale),
          )
          .clamped();
    });
  }

  // gesture handlers
  void _onScaleStart(ScaleStartDetails d, Size containerSize) {
    _gestureStartCrop = _crop;
    _gestureFocalStart = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size containerSize) {
    final startCrop = _gestureStartCrop;
    final newScale = (startCrop.scale * d.scale).clamp(
      1.0,
      PostCropTransform.maxScale,
    );

    // Pan: delta of focal point in normalised container coords
    final dX =
        (d.localFocalPoint.dx - _gestureFocalStart.dx) / containerSize.width;
    final dY =
        (d.localFocalPoint.dy - _gestureFocalStart.dy) / containerSize.height;

    setState(() {
      _crop = PostCropTransform(
        scale: newScale,
        offsetX: startCrop.offsetX + dX,
        offsetY: startCrop.offsetY + dY,
        cropLeft: startCrop.cropLeft,
        cropTop: startCrop.cropTop,
        cropRight: startCrop.cropRight,
        cropBottom: startCrop.cropBottom,
      ).clamped();
    });
  }

  // crop-frame resize
  void _onCropFrameChanged(Rect newFrame) {
    setState(() {
      _crop = PostCropTransform(
        scale: _crop.scale,
        offsetX: _crop.offsetX,
        offsetY: _crop.offsetY,
        cropLeft: newFrame.left,
        cropTop: newFrame.top,
        cropRight: newFrame.right,
        cropBottom: newFrame.bottom,
      ).clamped();
    });
  }

  // publish
  Future<void> _publish() async {
    final frozen = _frozenDraft;
    if (frozen == null || _isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      PostDraft draftToPublish = frozen.copyWith(
        caption: _captionController.text,
      );

      // On Web, we capture the cropped image from UI to ensure consistency
      // with what the user sees, avoiding any discrepancies in CPU-side cropping.
      if (kIsWeb && frozen.source.isImage) {
        final croppedBytes = await _captureFromUI();
        if (croppedBytes != null) {
          draftToPublish = draftToPublish.copyWith(
            source: frozen.source.copyWith(bytes: croppedBytes),
            crop: frozen.crop.copyWith(
              scale: 1.0,
              offsetX: 0.0,
              offsetY: 0.0,
              isBaked: true,
            ),
          );
        }
      }

      final thumbnailBytes = frozen.source.isVideo
          ? await _captureFromUI()
          : null;

      final post = await _publishService.publish(
        draftToPublish,
        videoThumbnailBytes: thumbnailBytes,
      );
      if (!mounted) return;
      context.read<PostFeedController>().insertAtTop(post);
      if (mounted) {
        final currentTheme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post publicado!'),
            backgroundColor: currentTheme.colorScheme.primary,
          ),
        );
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on PostPublishException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao publicar. Tenta novamente.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<Uint8List?> _captureFromUI() async {
    try {
      // Small delay to ensure the rendering is ready, especially for videos
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final boundary =
          _exportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Use a higher pixel ratio on web for better quality
      final image = await boundary.toImage(pixelRatio: kIsWeb ? 2.5 : 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = data?.buffer.asUint8List();
      if (pngBytes == null) return null;

      final decoded = img.decodePng(pngBytes);
      if (decoded == null) return null;
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
    } catch (_) {
      return null;
    }
  }

  //
  // BUILD
  //
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _frozenDraft;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (draft == null)
              _buildEditor(theme)
            else
              _buildFinalPreview(draft, theme),
            // Hidden high-quality export widget
            if (draft != null)
              Offstage(
                child: Center(
                  child: RepaintBoundary(
                    key: _exportKey,
                    child: PostCropExportWidget(
                      source: draft.source,
                      crop: draft.crop,
                    ),
                  ),
                ),
              ),
            // top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                isPreview: _isPreview,
                isPublishing: _isPublishing,
                onClose: _isPreview
                    ? _backToEdit
                    : () => Navigator.pop(context),
                onAction: _isPreview ? _publish : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // editor view
  Widget _buildEditor(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 56), // reserve space for top bar
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Fit 9:16 frame within available space
                final availW = constraints.maxWidth;
                final availH = constraints.maxHeight;
                double frameW, frameH;
                if (availW / availH > 9 / 16) {
                  frameH = availH;
                  frameW = frameH * 9 / 16;
                } else {
                  frameW = availW;
                  frameH = frameW * 16 / 9;
                }
                return Center(
                  child: SizedBox(
                    width: frameW,
                    height: frameH,
                    child: _MediaEditArea(
                      source: widget.source,
                      crop: _crop,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onCropFrameChanged: _onCropFrameChanged,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // zoom controls
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              _ZoomButton(
                icon: Icons.remove_rounded,
                onTap: () => _zoomBy(-0.15),
              ),
              const SizedBox(width: 12),
              _ZoomButton(icon: Icons.add_rounded, onTap: () => _zoomBy(0.15)),
              const SizedBox(width: 12),
              // zoom level indicator
              Text(
                '${(_crop.scale * 100).round()}%',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // preview view
  Widget _buildFinalPreview(PostDraft draft, ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 56),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availW = constraints.maxWidth;
                final availH = constraints.maxHeight;
                double frameW, frameH;
                if (availW / availH > 9 / 16) {
                  frameH = availH;
                  frameW = frameH * 9 / 16;
                } else {
                  frameW = availW;
                  frameH = frameW * 16 / 9;
                }
                return Center(
                  child: SizedBox(
                    width: frameW,
                    child: Center(
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: PostMediaFrame(
                          postId: 'preview_${draft.source.displaySource}',
                          source: draft.source,
                          crop: draft.crop,
                          autoplayVideo: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // caption field – respects keyboard inset
        AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: TextField(
            controller: _captionController,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Escreve uma descrição...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

//
// Media edit area – gesture detection + crop overlay
//

class _MediaEditArea extends StatelessWidget {
  const _MediaEditArea({
    required this.source,
    required this.crop,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onCropFrameChanged,
  });

  final PostMediaSource source;
  final PostCropTransform crop;
  final void Function(ScaleStartDetails, Size) onScaleStart;
  final void Function(ScaleUpdateDetails, Size) onScaleUpdate;
  final ValueChanged<Rect> onCropFrameChanged;

  @override
  Widget build(BuildContext context) {
    final cropFrame = Rect.fromLTRB(
      crop.cropLeft,
      crop.cropTop,
      crop.cropRight,
      crop.cropBottom,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // media (gesture target)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) => onScaleStart(d, containerSize),
                onScaleUpdate: (d) => onScaleUpdate(d, containerSize),
                child: PostMediaFrame(
                  postId: 'editor_${source.displaySource}',
                  source: source,
                  crop: crop,
                  isFullFrame: true,
                ),
              ),
              // dimmed overlay + dashed border
              IgnorePointer(
                child: CustomPaint(
                  painter: _CropOverlayPainter(cropFrame: cropFrame),
                ),
              ),
              // resize handles (interactive)
              _CropHandles(
                cropFrame: cropFrame,
                containerSize: containerSize,
                onChanged: onCropFrameChanged,
              ),
            ],
          ),
        );
      },
    );
  }
}

//
// Resizable handle overlay
//

enum _HandleEdge { left, right, top, bottom }

class _CropHandles extends StatelessWidget {
  const _CropHandles({
    required this.cropFrame,
    required this.containerSize,
    required this.onChanged,
  });

  final Rect cropFrame; // normalised 0-1
  final Size containerSize;
  final ValueChanged<Rect> onChanged;

  static const _hitSize = 36.0;
  static const _minCrop = 0.08;

  @override
  Widget build(BuildContext context) {
    final W = containerSize.width;
    final H = containerSize.height;

    final l = cropFrame.left * W;
    final t = cropFrame.top * H;
    final r = cropFrame.right * W;
    final b = cropFrame.bottom * H;
    final cx = (l + r) / 2;
    final cy = (t + b) / 2;

    return Stack(
      children: [
        // corners
        _handle(context, l, t, {_HandleEdge.left, _HandleEdge.top}, W, H),
        _handle(context, r, t, {_HandleEdge.right, _HandleEdge.top}, W, H),
        _handle(context, l, b, {_HandleEdge.left, _HandleEdge.bottom}, W, H),
        _handle(context, r, b, {_HandleEdge.right, _HandleEdge.bottom}, W, H),
        // edges
        _handle(context, cx, t, {_HandleEdge.top}, W, H),
        _handle(context, cx, b, {_HandleEdge.bottom}, W, H),
        _handle(context, l, cy, {_HandleEdge.left}, W, H),
        _handle(context, r, cy, {_HandleEdge.right}, W, H),
      ],
    );
  }

  Widget _handle(
    BuildContext context,
    double x,
    double y,
    Set<_HandleEdge> edges,
    double W,
    double H,
  ) {
    final isCorner = edges.length > 1;
    return Positioned(
      left: x - _hitSize / 2,
      top: y - _hitSize / 2,
      width: _hitSize,
      height: _hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          var l = cropFrame.left;
          var t = cropFrame.top;
          var r = cropFrame.right;
          var b = cropFrame.bottom;
          final dx = d.delta.dx / W;
          final dy = d.delta.dy / H;

          if (edges.contains(_HandleEdge.left)) {
            l = (l + dx).clamp(0.0, r - _minCrop);
          }
          if (edges.contains(_HandleEdge.right)) {
            r = (r + dx).clamp(l + _minCrop, 1.0);
          }
          if (edges.contains(_HandleEdge.top)) {
            t = (t + dy).clamp(0.0, b - _minCrop);
          }
          if (edges.contains(_HandleEdge.bottom)) {
            b = (b + dy).clamp(t + _minCrop, 1.0);
          }
          onChanged(Rect.fromLTRB(l, t, r, b));
        },
        child: Center(
          child: Container(
            width: isCorner ? 14.0 : 10.0,
            height: isCorner ? 14.0 : 10.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isCorner ? 3 : 5),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.35),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//
// Crop overlay painter – dims outside, dashed border, grid
//

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.cropFrame});

  final Rect cropFrame; // normalised 0-1

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      cropFrame.left * size.width,
      cropFrame.top * size.height,
      cropFrame.right * size.width,
      cropFrame.bottom * size.height,
    );

    // dim outside
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final dimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, dimPaint);

    // border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect, borderPaint);

    // rule-of-thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.7;
    final w3 = rect.width / 3;
    final h3 = rect.height / 3;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(rect.left + i * w3, rect.top),
        Offset(rect.left + i * w3, rect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + i * h3),
        Offset(rect.right, rect.top + i * h3),
        gridPaint,
      );
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    void line(Offset a, Offset b) {
      final vec = b - a;
      final dist = vec.distance;
      if (dist == 0) return;
      final dir = vec / dist;
      var pos = 0.0;
      while (pos < dist) {
        final end = math.min(pos + dash, dist);
        canvas.drawLine(a + dir * pos, a + dir * end, paint);
        pos += dash + gap;
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) => old.cropFrame != cropFrame;
}

//
// Small reusable widgets
//

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isPreview,
    required this.isPublishing,
    required this.onClose,
    required this.onAction,
  });

  final bool isPreview;
  final bool isPublishing;
  final VoidCallback onClose;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isPreview
                ? FilledButton(
                    onPressed: isPublishing ? null : onAction,
                    child: isPublishing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Publicar'),
                  )
                : FilledButton(
                    onPressed: onAction,
                    child: const Text('Seguinte'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        minimumSize: const Size(40, 40),
      ),
    );
  }
}

//
// Export-specific widget for high-quality capture
//

class PostCropExportWidget extends StatelessWidget {
  const PostCropExportWidget({
    super.key,
    required this.source,
    required this.crop,
  });

  final PostMediaSource source;
  final PostCropTransform crop;

  @override
  Widget build(BuildContext context) {
    // We target a base width of 1080 for high resolution capture.
    // PostMediaFrame uses the parent width to calculate its 9:16 base.
    return Center(
      child: SizedBox(
        width: 1080,
        height: 1920,
        child: PostMediaFrame(
          postId: 'export',
          source: source,
          crop: crop,
          autoplayVideo: true,
          isFullFrame: false,
        ),
      ),
    );
  }
}
