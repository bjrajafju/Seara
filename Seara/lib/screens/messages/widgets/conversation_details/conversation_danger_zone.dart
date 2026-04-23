import 'package:flutter/material.dart';

class ConversationDangerZone extends StatelessWidget {
  const ConversationDangerZone({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.error),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
