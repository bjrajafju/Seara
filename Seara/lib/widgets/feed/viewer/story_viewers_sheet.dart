import 'package:flutter/material.dart';
import '../../../controllers/story_engine_controller.dart';
import '../../../services/feed/story_management_service.dart';

class StoryViewersSheet extends StatefulWidget {
  final String storyId;
  final String mediaUrl;
  final StoryEngineController engine;

  const StoryViewersSheet({
    super.key,
    required this.storyId,
    required this.mediaUrl,
    required this.engine,
  });

  @override
  State<StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<StoryViewersSheet> {
  final _managementService = StoryManagementService();
  bool _isDeleting = false;
  late Future<List<Map<String, dynamic>>> _viewersFuture;

  @override
  void initState() {
    super.initState();
    _viewersFuture = _managementService.getStoryViewers(widget.storyId);
  }

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Eliminar story?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Esta ação não pode ser desfeita.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isDeleting = true;
      });

      try {
        await _managementService.deleteStory(widget.storyId, widget.mediaUrl);
        if (mounted) {
          Navigator.of(context).pop(true); // Pop sheet signaling deletion
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao eliminar momento'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Pull bar indicator
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Visualizações',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isDeleting)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                          size: 26,
                        ),
                        onPressed: _confirmDelete,
                      ),
                  ],
                ),
              ),
              Divider(color: theme.colorScheme.onSurface.withOpacity(0.1), height: 1),

              // Viewers list
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _viewersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erro ao carregar visualizações',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    final viewers = snapshot.data ?? [];

                    if (viewers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              color: theme.colorScheme.onSurface.withOpacity(0.2),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ainda sem visualizações',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: viewers.length,
                      itemBuilder: (context, index) {
                        final view = viewers[index];
                        final userJson =
                            view['users'] as Map<String, dynamic>? ?? {};
                        final username =
                            userJson['username'] as String? ?? 'user';
                        final avatarUrl =
                            userJson['avatar_url'] as String? ?? '';
                        final viewedAtStr = view['viewed_at'] as String?;
                        final viewedAt = viewedAtStr != null
                            ? DateTime.tryParse(viewedAtStr)
                            : null;

                        return StoryViewerTile(
                          username: username,
                          avatarUrl: avatarUrl,
                          viewedAt: viewedAt,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Delete loading overlay
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surface.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StoryViewerTile extends StatelessWidget {
  final String username;
  final String avatarUrl;
  final DateTime? viewedAt;

  const StoryViewerTile({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.viewedAt,
  });

  String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relativeTimeStr = _relativeTime(viewedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Text(
              username,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

          // Viewed time
          if (relativeTimeStr.isNotEmpty)
            Text(
              relativeTimeStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
