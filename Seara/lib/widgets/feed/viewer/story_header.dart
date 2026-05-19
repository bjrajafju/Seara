import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/story_engine_controller.dart';

/// Top-left overlay showing author avatar, username and relative time.
class StoryHeader extends StatelessWidget {
  final VoidCallback onClose;

  const StoryHeader({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final user = engine.currentUser;
    final story = engine.currentStory;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white24,
          backgroundImage: user.avatarUrl.isNotEmpty
              ? NetworkImage(user.avatarUrl)
              : null,
          child: user.avatarUrl.isEmpty
              ? Text(
                  user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),

        // Username + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              Text(
                _relativeTime(story.createdAt),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ],
          ),
        ),

        // Mute button
        _MuteButton(),
        const SizedBox(width: 4),

        // Close button
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 26),
          onPressed: onClose,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _MuteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StoryEngineController>();
    final story = engine.currentStory;

    // Only show mute button for video stories.
    if (!story.isVideo) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        engine.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: Colors.white,
        size: 24,
      ),
      onPressed: engine.toggleMute,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
