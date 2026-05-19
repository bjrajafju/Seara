import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/story_feed_controller.dart';
import '../../models/feed/story_user.dart';
import '../../screens/feed/story_viewer_screen.dart';
import '../../screens/story/create_story_screen.dart';
import 'story_bubble.dart';

/// Horizontal scrollable row of [StoryBubble] items.
///
/// Reads from [StoryFeedController] and handles loading/empty/error states.
/// Opens [StoryViewerScreen] when a bubble is tapped.
class StoriesRow extends StatefulWidget {
  const StoriesRow({super.key});

  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  @override
  void initState() {
    super.initState();
    // Fetch on first build, only if not already loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<StoryFeedController>();
      if (controller.users.isEmpty && !controller.isLoading) {
        controller.fetch();
      }
    });
  }

  void _openViewer(List<StoryUser> users, int initialIndex) {
    final tappedUser = users[initialIndex];
    if (tappedUser.stories.isEmpty) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CreateStoryScreen()));
      return;
    }

    final usersWithStories = users.where((u) => u.stories.isNotEmpty).toList();
    final newInitialIndex = usersWithStories.indexOf(tappedUser);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => StoryViewerScreen(
          users: usersWithStories,
          initialUserIndex: newInitialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryFeedController>(
      builder: (context, feed, _) {
        if (feed.isLoading && feed.users.isEmpty) {
          return const SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }

        if (feed.users.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: feed.users.length,
            itemBuilder: (context, index) {
              return StoryBubble(
                user: feed.users[index],
                onTap: () => _openViewer(feed.users, index),
              );
            },
          ),
        );
      },
    );
  }
}
