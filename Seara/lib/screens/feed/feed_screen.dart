import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/post_feed_controller.dart';
import '../../controllers/story_feed_controller.dart';
import '../../widgets/feed/feed_create_menu.dart';
import '../../widgets/feed/posts/posts_list.dart';
import '../../widgets/feed/stories_row.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 700) {
      context.read<PostFeedController>().fetchMore();
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<StoryFeedController>().fetch(refresh: true),
      context.read<PostFeedController>().fetch(refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.black,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: const [
            SliverToBoxAdapter(child: _FeedHeader()),
            SliverToBoxAdapter(
              child: Divider(color: Colors.white12, height: 1),
            ),
            PostsList(),
          ],
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Padding(padding: EdgeInsets.only(right: 54), child: StoriesRow()),
        Positioned(top: 28, right: 10, child: FeedCreateMenu()),
      ],
    );
  }
}
