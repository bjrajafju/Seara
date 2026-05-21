import 'package:flutter/material.dart';

import '../../../models/feed/feed_post.dart';
import '../../../models/feed/post_media_source.dart';
import 'post_media_frame.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = PostMediaSource(
      type: post.mediaType,
      mimeType: post.isVideo ? 'video/mp4' : 'image/jpeg',
      fileName: post.id,
      path: post.mediaUrl,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(post.avatarUrl),
                  backgroundColor: Colors.white12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PostMediaFrame(
            source: source,
            crop: post.crop,
            thumbnailUrl: post.thumbnailUrl,
            autoplayVideo: post.isVideo,
          ),
          if (post.caption != null && post.caption!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text.rich(
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
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
