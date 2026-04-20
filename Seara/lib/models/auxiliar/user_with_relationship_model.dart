class UserWithRelationship {
  final int id;
  final String username;
  final String name;
  final String avatarUrl;
  final bool iFollow;
  final bool followsMe;

  UserWithRelationship({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.iFollow,
    required this.followsMe,
  });

  bool get isMutual => iFollow && followsMe;

  int get sortWeight {
    if (isMutual) return 0;
    if (iFollow || followsMe) return 1;
    return 2;
  }

  factory UserWithRelationship.fromJson(Map<String, dynamic> json) {
    final avatar = (json['avatar_url'] ?? '').toString();
    return UserWithRelationship(
      id: json['id'] as int,
      username: (json['username'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      avatarUrl: avatar.isNotEmpty
          ? avatar
          : 'https://ui-avatars.com/api/?name=${json['username'] ?? 'User'}',
      iFollow: json['i_follow'] == true,
      followsMe: json['follows_me'] == true,
    );
  }
}
