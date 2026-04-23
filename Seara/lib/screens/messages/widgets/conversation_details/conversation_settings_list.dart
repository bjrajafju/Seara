import 'package:flutter/material.dart';

class ConversationSettingsItem {
  const ConversationSettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.iconColor,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback onTap;
}

class ConversationSettingsList extends StatelessWidget {
  const ConversationSettingsList({super.key, required this.items});

  final List<ConversationSettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items
          .map((item) => _ConversationSettingRow(item: item))
          .toList(),
    );
  }
}

class _ConversationSettingRow extends StatelessWidget {
  const _ConversationSettingRow({required this.item});

  final ConversationSettingsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (item.iconColor ?? theme.colorScheme.primary).withAlpha(
                  20,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: item.iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: item.titleColor,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                ],
              ),
            ),
            item.trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
          ],
        ),
      ),
    );
  }
}
