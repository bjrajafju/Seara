import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seara/controllers/post_feed_controller.dart';
import 'package:seara/widgets/feed/posts/posts_list.dart';

class UserPostsScreen extends StatelessWidget {
  final String authId;
  final String username;

  const UserPostsScreen({
    super.key,
    required this.authId,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PostFeedController(targetAuthId: authId),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Publicações de @$username'),
        ),
        body: const CustomScrollView(
          slivers: [
            PostsList(),
          ],
        ),
      ),
    );
  }
}
