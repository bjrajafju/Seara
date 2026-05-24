import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/post_feed_controller.dart';
import '../../../models/feed/feed_post.dart';
import '../../../models/feed/post_media_source.dart';
import '../../../services/feed/audio_preferences_service.dart';
import '../../../utils/time_helper.dart';
import '../../../utils/navigation_helper.dart';
import 'post_comments_sheet.dart';
import 'post_media_frame.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final FeedPost post;

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return PostCommentsSheet(
            post: post,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  void _showPostOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Eliminar post',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletion(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar este post?'),
        content: const Text('Esta ação não pode ser revertida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await context.read<PostFeedController>().deletePost(post.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post eliminado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao eliminar post: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = post.userId == currentUserId;

    final source = PostMediaSource(
      type: post.mediaType,
      mimeType: post.isVideo ? 'video/mp4' : 'image/jpeg',
      fileName: post.id,
      path: post.mediaUrl,
    );

    final width = MediaQuery.of(context).size.width;
    double cardWidth;
    double bottomMargin;

    if (width >= 1024) {
      cardWidth = 470; // ~1/3 screen width
      bottomMargin = 80;
    } else if (width >= 600) {
      cardWidth = 550; // tablet width
      bottomMargin = 48;
    } else {
      cardWidth = width; // full width on mobile
      bottomMargin = 32;
    }

    return Center(
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(bottom: bottomMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => NavigationHelper.openProfile(context, post.userDbId),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(post.avatarUrl),
                            backgroundColor: theme.colorScheme.onSurface.withOpacity(
                              0.1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            post.username,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '•',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatRelativeTime(post.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                  if (isOwner) ...[
                    const Spacer(),
                    if (width >= 1024)
                      PopupMenuButton<String>(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        icon: Icon(
                          Icons.more_horiz,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDeletion(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Eliminar post',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.more_horiz,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        onPressed: () => _showPostOptionsMenu(context),
                      ),
                  ],
                ],
              ),
            ),

            // Media
            Center(
              child: PostMediaFrame(
                postId: post.id,
                source: source,
                crop: post.crop,
                thumbnailUrl: post.thumbnailUrl,
                autoplayVideo: post.isVideo,
              ),
            ),

            // Actions row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked
                          ? Colors.red
                          : theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      context.read<PostFeedController>().toggleLike(post.id);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.mode_comment_outlined,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => _showCommentsSheet(context),
                  ),
                  const Spacer(),
                  if (post.isVideo)
                    ValueListenableBuilder<bool>(
                      valueListenable: AudioPreferencesService.isMutedNotifier,
                      builder: (context, isMuted, _) {
                        return IconButton(
                          icon: Icon(
                            isMuted ? Icons.volume_off : Icons.volume_up,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () {
                            AudioPreferencesService.setMuted(!isMuted);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),

            // Like count, Caption, Comments link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.likeCount == 1
                        ? '1 gosto'
                        : '${post.likeCount} gostos',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (post.caption != null &&
                      post.caption!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () => NavigationHelper.openProfile(context, post.userDbId),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  '${post.username} ',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                          TextSpan(text: post.caption!.trim()),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (post.commentCount > 0) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showCommentsSheet(context),
                      child: Text(
                        'Ver todos os ${post.commentCount} comentários',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
