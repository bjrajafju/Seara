import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/post_feed_controller.dart';
import '../../../models/feed/feed_post.dart';
import '../../../models/feed/post_media_source.dart';
import '../../../services/feed/audio_preferences_service.dart';
import '../../../utils/time_helper.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = PostMediaSource(
      type: post.mediaType,
      mimeType: post.isVideo ? 'video/mp4' : 'image/jpeg',
      fileName: post.id,
      path: post.mediaUrl,
    );

    final width = MediaQuery.of(context).size.width;
    double cardWidth;
    if (width >= 1024) {
      cardWidth = 470; // ~1/3 screen width
    } else if (width >= 600) {
      cardWidth = 550; // tablet width
    } else {
      cardWidth = width; // full width on mobile
    }

    return Center(
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(post.avatarUrl),
                    backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    post.username,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
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
                ],
              ),
            ),

            // Media
            PostMediaFrame(
              source: source,
              crop: post.crop,
              thumbnailUrl: post.thumbnailUrl,
              autoplayVideo: post.isVideo,
            ),

            // Actions row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : theme.colorScheme.onSurface,
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
                    post.likeCount == 1 ? '1 gosto' : '${post.likeCount} gostos',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (post.caption != null && post.caption!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${post.username} ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
