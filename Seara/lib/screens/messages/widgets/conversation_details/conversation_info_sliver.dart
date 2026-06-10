import 'package:flutter/material.dart';

class ConversationInfoSliver extends StatelessWidget {
  const ConversationInfoSliver({
    super.key,
    required this.isGroup,
    required this.isAdmin,
    required this.displayAvatar,
    required this.displayName,
    required this.membersLabel,
    required this.description,
    required this.usernameLabel,
    required this.canEditBio,
    required this.onBack,
    required this.onOpenProfile,
    required this.onOpenEditGroup,
    required this.onEditDescription,
  });

  final bool isGroup;
  final bool isAdmin;
  final String? displayAvatar;
  final String displayName;
  final String? membersLabel;
  final String? description;
  final String? usernameLabel;
  final bool canEditBio;
  final VoidCallback onBack;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenEditGroup;
  final VoidCallback onEditDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      pinned: true,
      expandedHeight: 260,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: onBack,
      ),
      actions: [
        if (!isGroup && onOpenProfile != null)
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Ver perfil',
            onPressed: onOpenProfile,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: Column(
              children: [
                GestureDetector(
                  onTap: isGroup
                      ? (isAdmin ? onOpenEditGroup : null)
                      : onOpenProfile,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            displayAvatar != null && displayAvatar!.isNotEmpty
                            ? NetworkImage(displayAvatar!)
                            : null,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: displayAvatar == null || displayAvatar!.isEmpty
                            ? Icon(
                                isGroup ? Icons.group_rounded : Icons.person,
                                size: 48,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      if (isGroup && isAdmin)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: isGroup
                      ? (isAdmin ? onOpenEditGroup : null)
                      : onOpenProfile,
                  child: Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (isGroup && membersLabel != null)
                  Text(
                    membersLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                if (isGroup && description != null && description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: canEditBio ? onEditDescription : null,
                      child: Text(
                        description!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(180),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (isGroup &&
                    (description == null || description!.isEmpty) &&
                    canEditBio)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: onEditDescription,
                      child: Text(
                        'Adicionar descrição...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withAlpha(150),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                if (!isGroup && usernameLabel != null)
                  Text(
                    usernameLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
