import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/post_feed_controller.dart';
import 'post_card.dart';

class PostsList extends StatefulWidget {
  const PostsList({super.key});

  @override
  State<PostsList> createState() => _PostsListState();
}

class _PostsListState extends State<PostsList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<PostFeedController>();
      if (controller.posts.isEmpty && !controller.isLoading) {
        controller.fetch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostFeedController>(
      builder: (context, controller, _) {
        if (controller.isLoading && controller.posts.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (controller.error != null && controller.posts.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Não foi possível carregar os posts.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
              ),
            ),
          );
        }

        if (controller.posts.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Ainda não há posts.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
              ),
            ),
          );
        }

        final itemCount =
            controller.posts.length + (controller.isLoadingMore ? 1 : 0);
        return SliverList.builder(
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= controller.posts.length) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            return PostCard(post: controller.posts[index]);
          },
        );
      },
    );
  }
}
