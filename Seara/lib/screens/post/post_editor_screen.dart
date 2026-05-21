import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../controllers/post_feed_controller.dart';
import '../../models/feed/post_crop_transform.dart';
import '../../models/feed/post_media_source.dart';
import '../../services/feed/post_publish_service.dart';
import '../../utils/media/blob_url_helper.dart'
    if (dart.library.html) '../../utils/media/blob_url_helper_web.dart';
import '../../widgets/feed/posts/post_media_frame.dart';

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

  PostCropTransform _crop = PostCropTransform.identity;
  PostDraft? _frozenDraft;
  bool _isPublishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    if (widget.source.previewUrl?.startsWith('blob:') == true) {
      revokeBlobUrl(widget.source.previewUrl);
    }
    super.dispose();
  }

  bool get _isPreview => _frozenDraft != null;

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

  void _zoomBy(double delta) {
    setState(() {
      _crop = _crop
          .copyWith(scale: (_crop.scale + delta).clamp(1.0, 3.0))
          .clamped();
    });
  }

  Future<void> _publish() async {
    final frozen = _frozenDraft;
    if (frozen == null || _isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      final thumbnailBytes = frozen.source.isVideo
          ? await _captureVideoThumbnail()
          : null;
      final post = await _publishService.publish(
        frozen.copyWith(caption: _captionController.text),
        videoThumbnailBytes: thumbnailBytes,
      );
      if (!mounted) return;
      context.read<PostFeedController>().insertAtTop(post);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post publicado!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on PostPublishException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erro ao publicar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<Uint8List?> _captureVideoThumbnail() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final boundary =
          _previewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = data?.buffer.asUint8List();
      if (pngBytes == null) return null;
      final decoded = img.decodePng(pngBytes);
      if (decoded == null) return null;
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 82));
    } catch (_) {
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _frozenDraft;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (draft == null) _buildEditor() else _buildFinalPreview(draft),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: _isPreview
                    ? _backToEdit
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: _isPreview
                  ? _PublishButton(isPublishing: _isPublishing, onTap: _publish)
                  : _NextButton(onTap: _next),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 1.2),
                ),
                child: PostMediaFrame(
                  source: widget.source,
                  crop: _crop,
                  editable: true,
                  onCropChanged: (crop) => setState(() => _crop = crop),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(child: _DashedBorder()),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Row(
            children: [
              _RoundToolButton(
                icon: Icons.remove_rounded,
                onTap: () => _zoomBy(-0.12),
              ),
              const SizedBox(width: 12),
              _RoundToolButton(
                icon: Icons.add_rounded,
                onTap: () => _zoomBy(0.12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalPreview(PostDraft draft) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: RepaintBoundary(
                key: _previewKey,
                child: PostMediaFrame(
                  source: draft.source,
                  crop: draft.crop,
                  autoplayVideo: true,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: TextField(
            controller: _captionController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Escreve uma descrição...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
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

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onTap, child: const Text('Seguinte'));
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.isPublishing, required this.onTap});

  final bool isPublishing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isPublishing ? null : onTap,
      child: isPublishing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Publicar'),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  const _RoundToolButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedBorderPainter());
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 8.0;
    const gap = 5.0;

    void drawDashedLine(Offset start, Offset end) {
      final vector = end - start;
      final distance = vector.distance;
      final direction = vector / distance;
      var drawn = 0.0;
      while (drawn < distance) {
        final segment = (drawn + dash).clamp(0.0, distance);
        canvas.drawLine(
          start + direction * drawn,
          start + direction * segment,
          paint,
        );
        drawn += dash + gap;
      }
    }

    drawDashedLine(Offset.zero, Offset(size.width, 0));
    drawDashedLine(Offset(size.width, 0), Offset(size.width, size.height));
    drawDashedLine(Offset(size.width, size.height), Offset(0, size.height));
    drawDashedLine(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
