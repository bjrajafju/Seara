import 'package:flutter/material.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';
import 'widgets/posts_grid.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId; // podes usar para carregar dados reais depois

  const ProfileScreen({Key? key, this.userId = 'me'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // mock: nome, bio, avatar (substitui por dados reais mais tarde)
    final String name = 'Daniel';
    final String bio = 'Desenvolvedor · Criador · A fazer Seara';
    final String avatarUrl =
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=80';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // abre página de definições (já existente)
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // aqui podes recarregar dados do backend
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (avatar, name, bio, botões)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: ProfileHeader(
                  avatarUrl: avatarUrl,
                  name: name,
                  bio: bio,
                  onEditProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
              ),

              // Stats row (posts, followers, following)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ProfileStats(
                  posts: 24,
                  followers: 1280,
                  following: 312,
                  onFollowersTap: () {
                    Navigator.pushNamed(
                      context,
                      '/followers',
                      arguments: userId,
                    );
                  },
                  onFollowingTap: () {
                    Navigator.pushNamed(
                      context,
                      '/following',
                      arguments: userId,
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Tabs (Posts / Reels / Tagged) simple placeholder
              _buildTabsRow(),

              const Divider(height: 1),

              // Posts grid
              const PostsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: const [
          Expanded(
            child: IconRowButton(
              icon: Icons.grid_on,
              label: 'Posts',
              active: true,
            ),
          ),
          Expanded(
            child: IconRowButton(
              icon: Icons.video_collection_outlined,
              label: 'Reels',
            ),
          ),
          Expanded(
            child: IconRowButton(
              icon: Icons.person_pin_outlined,
              label: 'Tagged',
            ),
          ),
        ],
      ),
    );
  }
}

class IconRowButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const IconRowButton({
    Key? key,
    required this.icon,
    required this.label,
    this.active = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.grey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
