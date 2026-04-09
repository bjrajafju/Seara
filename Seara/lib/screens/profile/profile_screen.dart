import 'package:flutter/material.dart';
import 'package:seara/services/profile_service.dart';
import 'edit_profile_screen.dart';
import 'package:seara/models/profile_model.dart';
import 'package:seara/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});
  final int? userId;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const List<Tab> postTabs = <Tab>[
    Tab(text: 'Posts'),
    Tab(text: 'Reposts'),
    Tab(text: 'Mentioned'),
  ];

  late TabController _tabController;
  Profile? profile;
  bool isLoading = true;
  bool isFollowing = false;
  bool _isProcessingFollow = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: postTabs.length);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      bool isFollowingAsync;
      int? userId = widget.userId;
      if (userId == null) {
        userId = await AuthService.getUserId();
        if (userId == null) return;
        isFollowingAsync = true;
      } else {
        int? myId = await AuthService.getUserId();
        if (myId == null) return;
        isFollowingAsync = await ProfileService.isFollowing(
          followerId: myId,
          followingId: userId,
        );
      }

      final result = await ProfileService.getProfile(userId);

      setState(() {
        profile = result;
        isLoading = false;
        isFollowing = isFollowingAsync;
      });
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _follow() async {
    if (_isProcessingFollow) return;

    final myId = await AuthService.getUserId();
    final userId = widget.userId;

    if (myId == null || userId == null) return;

    setState(() => _isProcessingFollow = true);

    final previousState = isFollowing;
    final previousFollowers = profile!.followers;

    setState(() {
      isFollowing = !isFollowing;
      profile = Profile(
        id: profile!.id,
        username: profile!.username,
        name: profile!.name,
        bio: profile!.bio,
        avatarUrl: profile!.avatarUrl,
        posts: profile!.posts,
        followers: isFollowing ? previousFollowers + 1 : previousFollowers - 1,
        following: profile!.following,
      );
    });

    try {
      await ProfileService.follow(
        followerId: myId,
        followingId: userId,
        isFollowing: previousState,
      );
    } catch (e) {
      setState(() {
        isFollowing = previousState;
        profile = Profile(
          id: profile!.id,
          username: profile!.username,
          name: profile!.name,
          bio: profile!.bio,
          avatarUrl: profile!.avatarUrl,
          posts: profile!.posts,
          followers: previousFollowers,
          following: profile!.following,
        );
      });
    } finally {
      if (mounted) setState(() => _isProcessingFollow = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Build Widgets ----------

  Widget _buildAvatarSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(profile!.avatarUrl),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameUsername(theme),
            const SizedBox(height: 8),
            _buildStatsRow(theme),
          ],
        ),
      ],
    );
  }

  Widget _buildNameUsername(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile!.name.isNotEmpty ? profile!.name : profile!.username,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '@${profile!.username}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Row(
      children: [
        _buildStatItem(theme, profile!.posts.toString(), 'Posts'),
        const SizedBox(width: 16),
        _buildStatItem(theme, profile!.following.toString(), 'Following'),
        const SizedBox(width: 16),
        _buildStatItem(theme, profile!.followers.toString(), 'Followers'),
      ],
    );
  }

  Widget _buildStatItem(ThemeData theme, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        profile!.bio,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildButtonsRow(ThemeData theme) {
    final isMyProfile = widget.userId == null;

    return Row(
      children: [
        if (isMyProfile)
          TextButton(
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(profile: profile!),
                ),
              );
              if (updated == true) _loadProfile();
            },
            child: const Text('Editar Perfil'),
          ),
        TextButton(onPressed: () {}, child: const Text('Partilhar Perfil')),
        if (!isMyProfile)
          TextButton(
            onPressed: _isProcessingFollow ? null : _follow,
            child: _isProcessingFollow
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isFollowing ? 'Unfollow' : 'Follow'),
          ),
        if (!isMyProfile)
          TextButton(onPressed: () {}, child: const Text('Message')),
      ],
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      children: [
        _buildAvatarSection(theme),
        _buildBioSection(theme),
        _buildButtonsRow(theme),
      ],
    );
  }

  Widget _buildPostsGrid(ThemeData theme) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 60,
      itemBuilder: (context, index) {
        return Container(
          color: theme.colorScheme.surfaceContainerHighest,
        );
      },
    );
  }

  // ---------- Build Main ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _buildProfileHeader(theme)),
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 0,
              bottom: TabBar(controller: _tabController, tabs: postTabs),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsGrid(theme),
            _buildPostsGrid(theme),
            _buildPostsGrid(theme),
          ],
        ),
      ),
    );
  }
}
