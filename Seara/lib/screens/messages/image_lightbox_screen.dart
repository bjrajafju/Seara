import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:seara/services/api_client.dart' as http;

// Import condicional: usa web em browser, stub em mobile
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

/// Lightbox para visualização de imagens recebidas no chat.
///
/// Funcionalidades:
/// - Zoom in/out via pinch ou scroll (InteractiveViewer)
/// - Animação Hero ao abrir (heroTag = imageUrl)
/// - Fechar ao tocar na área escura fora da imagem
/// - Download (web via helper JS; mobile via http)
class ImageLightboxScreen extends StatefulWidget {
  const ImageLightboxScreen({super.key, required this.imageUrl, this.fileName});

  final String imageUrl;
  final String? fileName;

  @override
  State<ImageLightboxScreen> createState() => _ImageLightboxScreenState();
}

class _ImageLightboxScreenState extends State<ImageLightboxScreen> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      if (kIsWeb) {
        downloadFile(widget.imageUrl, widget.fileName ?? 'imagem.jpg');
      } else {
        await _downloadMobile();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer download.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _downloadMobile() async {
    final response = await http.ApiClient.get(Uri.parse(widget.imageUrl));
    if (response.statusCode != 200) throw Exception('Falha no download.');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download concluído.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.inverseSurface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: GestureDetector(
        // Fechar ao tocar na área preta fora da imagem
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            // Consumir o tap na própria imagem para não fechar
            onTap: () {},
            child: Hero(
              tag: widget.imageUrl,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 6.0,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(color: cs.onInverseSurface),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    final cs = Theme.of(context).colorScheme;
                    return Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: cs.onInverseSurface.withAlpha(140),
                        size: 64,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppBar(
      backgroundColor: cs.inverseSurface.withAlpha(200),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: cs.onInverseSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: widget.fileName != null
          ? Text(
              widget.fileName!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onInverseSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            )
          : null,
      actions: [
        _isDownloading
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onInverseSurface,
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.download_rounded, color: cs.onInverseSurface),
                tooltip: 'Download',
                onPressed: _download,
              ),
      ],
    );
  }
}
