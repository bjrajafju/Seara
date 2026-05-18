import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildRing(), const SizedBox(height: 5), _buildLabel()],
        ),
      ),
    );
  }

  Widget _buildRing() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: user.hasUnseen ? _unseenGradient : null,
        color: user.hasUnseen ? null : const Color(0xFF8E8E8E),
      ),
      padding: const EdgeInsets.all(2.5), // ring thickness
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black, // separator between ring and avatar
        ),
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          backgroundColor: const Color(0xFF333333),
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
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLabel() {
    return SizedBox(
      width: 68,
      child: Text(
        user.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
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
