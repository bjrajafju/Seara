import 'package:flutter/material.dart';
import 'package:seara/services/profile/profile_service.dart';
import 'package:seara/services/auth_service.dart';
import 'package:seara/services/messages_service.dart';
import 'package:seara/screens/messages/conversation_screen.dart';
import 'edit_profile_screen.dart';
import 'user_posts_screen.dart';
import 'package:seara/models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});
  final int? userId;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? profile;
  bool isLoading = true;
  bool isFollowing = false;
  bool _isProcessingFollow = false;
  bool _isCreatingMessage = false;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Loads profile
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

  /// Follow
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
        authId: profile!.authId,
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
          authId: profile!.authId,
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

  /// Starts message
  Future<void> _startMessage() async {
    if (_isCreatingMessage) return;

    final myId = await AuthService.getUserId();
    final userId = widget.userId;

    if (myId == null || userId == null) return;

    setState(() => _isCreatingMessage = true);

    try {
      final messagesService = MessagesService();
      final conversation = await messagesService.createConversation(
        creatorId: myId,
        participantIds: [userId],
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao iniciar conversa: $e')));
    } finally {
      if (mounted) setState(() => _isCreatingMessage = false);
    }
  }

  @override
  /// Releases controllers and subscriptions used by this widget
  void dispose() {
    super.dispose();
  }

  /// Builds avatar section
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

  /// Builds name username
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

  /// Builds stats row
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

  /// Builds stat item
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

  /// Builds bio section
  Widget _buildBioSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(profile!.bio, style: theme.textTheme.bodyMedium),
    );
  }

  /// Builds buttons row
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
          TextButton(
            onPressed: _isCreatingMessage ? null : _startMessage,
            child: _isCreatingMessage
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Message'),
          ),
      ],
    );
  }

  /// Builds profile header
  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      children: [
        _buildAvatarSection(theme),
        _buildBioSection(theme),
        _buildButtonsRow(theme),
      ],
    );
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(theme),
            const Divider(),
            if (widget.userId == null || isFollowing)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserPostsScreen(
                          authId: profile!.authId,
                          username: profile!.username,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.grid_view),
                  label: const Text('Ver publicações'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
