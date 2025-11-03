import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileStats({
    Key? key,
    required this.posts,
    required this.followers,
    required this.following,
    this.onFollowersTap,
    this.onFollowingTap,
  }) : super(key: key);

  Widget _buildStat(String label, String value, VoidCallback? onTap) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: content);
    } else {
      return content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStat('Publicações', posts.toString(), null),
        _buildStat('Seguidores', _formatNumber(followers), onFollowersTap),
        _buildStat('Seguindo', _formatNumber(following), onFollowingTap),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
