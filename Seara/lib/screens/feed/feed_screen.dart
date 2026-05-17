import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/story_feed_controller.dart';
import '../../widgets/feed/stories_row.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.black,
        onRefresh: () => context.read<StoryFeedController>().fetch(),
        child: CustomScrollView(
          slivers: [
            // ── Stories Row ─────────────────────────────────────────────────
            const SliverToBoxAdapter(child: StoriesRow()),

            // ── Divider ─────────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Divider(color: Colors.white12, height: 1),
            ),

            // ── Feed placeholder ─────────────────────────────────────────────
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dynamic_feed_rounded,
                      size: 64,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Feed a chegar em breve',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
