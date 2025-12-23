import 'package:flutter/material.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';
import 'widgets/posts_grid.dart';
import 'widgets/ship_grid.dart';
import 'widgets/tagged_grid.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: postTabs.length);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // perfil todo
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Image.network(
                          'https://picsum.photos/seed/481/600',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Daniel"),
                          Row(
                            children: [
                              Column(children: [Text("999"), Text("Posts")]),
                              Column(
                                children: [Text("999"), Text("Following")],
                              ),
                              Column(
                                children: [Text("999"), Text("Followers")],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text("Bio"),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text("Editar Perfil"),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text("Partilhar Perfil"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // headers dos posts
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 0,
              bottom: TabBar(controller: _tabController, tabs: postTabs),
            ),
          ];
        },

        // posts
        body: TabBarView(
          controller: _tabController,
          children: [_postsGrid(), _postsGrid(), _postsGrid()],
        ),
      ),
    );
  }
}

Widget _postsGrid() {
  return GridView.builder(
    padding: EdgeInsets.zero,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
