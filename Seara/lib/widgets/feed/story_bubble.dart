import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/feed/story_user.dart';

/// A single circular avatar with a coloured ring (unseen) or grey ring (seen).
///
/// Tapping triggers [onTap] which opens the [StoryViewerScreen] at this user.
class StoryBubble extends StatelessWidget {
  final StoryUser user;
  final VoidCallback onTap;

  const StoryBubble({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRing(theme),
            const SizedBox(height: 5),
            _buildLabel(theme)
          ],
        ),
      ),
    );
  }

  Widget _buildRing(ThemeData theme) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnEmptyStory =
        user.userId == currentUserId && user.stories.isEmpty;

    return Stack(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: user.hasUnseen ? _unseenGradient : null,
            color: user.hasUnseen ? null : theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          padding: const EdgeInsets.all(2.5), // ring thickness
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface, // separator between ring and avatar
            ),
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? NetworkImage(user.avatarUrl)
                  : null,
              child: user.avatarUrl.isEmpty
                  ? Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (isOwnEmptyStory)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildLabel(ThemeData theme) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final displayName = user.userId == currentUserId
        ? 'O teu story'
        : user.username;

    return SizedBox(
      width: 68,
      child: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static const _unseenGradient = LinearGradient(
    colors: [
      Color(0xFFF58529), // orange
      Color(0xFFDD2A7B), // pink
      Color(0xFF8134AF), // purple
      Color(0xFF515BD4), // blue
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
}
