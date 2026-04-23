import 'package:flutter/material.dart';
import 'package:seara/models/link_preview_model.dart';
import 'package:seara/screens/messages/image_lightbox_screen.dart';
import 'package:seara/screens/messages/video_lightbox_screen.dart';
import 'package:seara/screens/messages/widgets/link_preview_card.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/services/link_preview_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ConversationStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const ConversationStickyTabBarDelegate({
    required this.tabBar,
    required this.color,
  });

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant ConversationStickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || color != oldDelegate.color;
  }
}

class ConversationMediaGrid extends StatefulWidget {
  const ConversationMediaGrid({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.type,
  });

  final int conversationId;
  final int userId;
  final String type;

  @override
  State<ConversationMediaGrid> createState() => _ConversationMediaGridState();
}

class _ConversationMediaGridState extends State<ConversationMediaGrid>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await ConversationSettingsService.getSharedMedia(
        widget.conversationId,
        widget.userId,
        type: widget.type,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 36,
              color: theme.colorScheme.error.withAlpha(150),
            ),
            const SizedBox(height: 8),
            Text(
              'Erro ao carregar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      IconData emptyIcon;
      String emptyText;
      switch (widget.type) {
        case 'media':
          emptyIcon = Icons.photo_library_outlined;
          emptyText = 'Sem multimédia partilhada.';
          break;
        case 'file':
          emptyIcon = Icons.folder_outlined;
          emptyText = 'Sem ficheiros partilhados.';
          break;
        case 'link':
          emptyIcon = Icons.link_off_rounded;
          emptyText = 'Sem links partilhados.';
          break;
        default:
          emptyIcon = Icons.folder_open_rounded;
          emptyText = 'Sem conteúdo.';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emptyIcon,
                size: 48,
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
              const SizedBox(height: 12),
              Text(
                emptyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.type == 'media') {
      return GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isVideo = (item['attachment_type'] ?? '').toString().startsWith(
            'video',
          );
          final url = item['attachment'] ?? '';
          return GestureDetector(
            onTap: () {
              if (isVideo) {
                _openVideoPlayer(context, url);
              } else {
                _openImageViewer(context, url);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: theme.colorScheme.onSurface.withAlpha(80),
                    ),
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.scrim.withAlpha(140),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: theme.colorScheme.onInverseSurface,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    if (widget.type == 'link') {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final body = item['body'] ?? '';
          final urlMatch = RegExp(r'(https?://[^\s]+)').firstMatch(body);
          final url = urlMatch?.group(0) ?? body;
          return InkWell(
            onTap: () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<LinkPreview?>(
                    future: LinkPreviewService.fetchLinkPreview(url),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return LinkPreviewCard(preview: snapshot.data!);
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.link_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          url,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatDate(
                            DateTime.tryParse(item['created_at'] ?? ''),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final name = item['attachment_name'] ?? 'Ficheiro';
        final url = item['attachment'] ?? '';
        return ListTile(
          onTap: () => _confirmDownload(context, url, name),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatDate(DateTime.tryParse(item['created_at'] ?? '')),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          trailing: Icon(
            Icons.download_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _openImageViewer(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Theme.of(context).colorScheme.scrim,
        pageBuilder: (_, __, ___) => ImageLightboxScreen(imageUrl: url),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Theme.of(context).colorScheme.scrim,
        pageBuilder: (_, __, ___) => VideoLightboxScreen(videoUrl: url),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _confirmDownload(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deseja fazer download de:'),
            const SizedBox(height: 8),
            Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final uri = Uri.tryParse(url);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
