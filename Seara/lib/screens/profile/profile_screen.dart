import 'package:flutter/material.dart';
import 'package:seara/services/profile_service.dart';
import 'edit_profile_screen.dart';
import 'package:seara/models/profile_model.dart';
import 'package:seara/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});
  final int? userId; // se null, é o meu perfil

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: postTabs.length);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      int? userId = widget.userId;
      if (userId == null) {
        userId = await AuthService.getUserId();
        if (userId == null) return;
      }

      

      final result = await ProfileService.getProfile(userId);

      setState(() {
        profile = result;
        isLoading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Build Widgets ----------

  Widget _buildAvatarSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(shape: BoxShape.circle),
          child: Image.network(profile!.avatarUrl, fit: BoxFit.cover),
        ),

        // Nome, username e stats
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameUsername(),
            const SizedBox(height: 8),
            _buildStatsRow(),
          ],
        ),
      ],
    );
  }

  Widget _buildNameUsername() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile!.name.isNotEmpty ? profile!.name : profile!.username,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          '@${profile!.username}',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatItem(profile!.posts.toString(), "Posts"),
        const SizedBox(width: 16),
        _buildStatItem(profile!.following.toString(), "Following"),
        const SizedBox(width: 16),
        _buildStatItem(profile!.followers.toString(), "Followers"),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label),
      ],
    );
  }

  Widget _buildBioSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(profile!.bio),
    );
  }

  Widget _buildButtonsRow() {
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
            child: const Text("Editar Perfil"),
          ),
        TextButton(onPressed: () {}, child: const Text("Partilhar Perfil")),
        
        TextButton(onPressed: () {}, child: const Text("Follow")),
        TextButton(onPressed: () {}, child: const Text("Message")),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [_buildAvatarSection(), _buildBioSection(), _buildButtonsRow()],
    );
  }

  Widget _buildPostsGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 60,
      itemBuilder: (context, index) {
        return Container(color: Colors.grey);
      },
    );
  }

  // ---------- Build Main ----------

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _buildProfileHeader()),
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
          children: [_buildPostsGrid(), _buildPostsGrid(), _buildPostsGrid()],
        ),
      ),
    );
  }
}
