class Profile {
  final int id;
  final String username;
  final String bio;
  final String avatarUrl;
  final int posts;
  final int followers;
  final int following;

  Profile({
    required this.id,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.posts,
    required this.followers,
    required this.following,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      username: json['username'] ?? '',
      bio: json['bio'] ?? '',
      avatarUrl:
          json['avatar_url'] ??
          'https://ui-avatars.com/api/?name=${json['username'] ?? 'User'}',
      posts: json['posts_count'] ?? 0,
      followers: json['followers_count'] ?? 0,
      following: json['following_count'] ?? 0,
    );
  }
}
