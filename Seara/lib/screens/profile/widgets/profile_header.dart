import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final String bio;
  final VoidCallback? onEditProfile;

  const ProfileHeader({
    Key? key,
    required this.avatarUrl,
    required this.name,
    required this.bio,
    this.onEditProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 42,
          backgroundImage: NetworkImage(avatarUrl),
          backgroundColor: Colors.grey[800],
        ),
        const SizedBox(width: 16),

        // Name, bio and buttons
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Edit button row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onEditProfile,
                    child: const Text('Editar perfil'),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Bio
              Text(
                bio,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 8),

              // Quick action row (Follow, Message, More)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // seguir / unfollow => ligar a backend depois
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Seguir'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // abrir mensagem direta
                    },
                    icon: const Icon(Icons.message_outlined),
                    label: const Text('Mensagem'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
