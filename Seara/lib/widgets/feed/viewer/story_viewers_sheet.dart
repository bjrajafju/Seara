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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Eliminar story?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Esta ação não pode ser desfeita.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.redAccent,
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
              content: Text('Erro ao eliminar story'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                    color: Colors.white30,
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
                    const Text(
                      'Visualizações',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isDeleting)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                        onPressed: _confirmDelete,
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Viewers list
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _viewersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Erro ao carregar visualizações',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    final viewers = snapshot.data ?? [];

                    if (viewers.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              color: Colors.white24,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Ainda sem visualizações',
                              style: TextStyle(
                                color: Colors.white54,
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
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
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
    final relativeTimeStr = _relativeTime(viewedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

          // Viewed time
          if (relativeTimeStr.isNotEmpty)
            Text(
              relativeTimeStr,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
