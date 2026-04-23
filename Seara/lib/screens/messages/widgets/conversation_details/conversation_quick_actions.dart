import 'package:flutter/material.dart';

class ConversationQuickActionItem {
  const ConversationQuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class ConversationQuickActions extends StatelessWidget {
  const ConversationQuickActions({super.key, required this.actions});

  final List<ConversationQuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) {
          return GestureDetector(
            onTap: action.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    action.icon,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
