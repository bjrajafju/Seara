class Profile {
  final int id;
  final String authId;
  final String username;
  final String name;
  final String bio;
  final String avatarUrl;
  final int posts;
  final int followers;
  final int following;

  Profile({
    required this.id,
    required this.authId,
    required this.username,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    required this.posts,
    required this.followers,
    required this.following,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as int,
      authId: (json['auth_id'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      bio: (json['bio'] ?? '') as String,
      avatarUrl: (json['avatar_url'] ?? '').toString().isNotEmpty
          ? json['avatar_url']
          : 'https://ui-avatars.com/api/?name=${json['username'] ?? 'User'}',
      posts: json['posts_count'] ?? 0,
      followers: json['followers_count'] ?? 0,
      following: json['following_count'] ?? 0,
    );
  }
}
