import 'package:flutter/material.dart';

import '../../screens/post/create_post_screen.dart';
import '../../screens/story/create_story_screen.dart';

class FeedCreateMenu extends StatelessWidget {
  const FeedCreateMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CreateTarget>(
      tooltip: 'Criar',
      color: Theme.of(context).colorScheme.surface,
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 30),
      onSelected: (target) {
        switch (target) {
          case _CreateTarget.story:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
            );
          case _CreateTarget.post:
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _CreateTarget.story,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.auto_stories_rounded),
            title: Text('Story'),
          ),
        ),
        PopupMenuItem(
          value: _CreateTarget.post,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.photo_library_rounded),
            title: Text('Post'),
          ),
        ),
      ],
    );
  }
}

enum _CreateTarget { story, post }
