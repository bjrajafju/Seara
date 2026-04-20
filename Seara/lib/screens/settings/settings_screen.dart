import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  // Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Aparência',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.onSurface.withAlpha(18), width: 1),
            ),
            child: Consumer<ThemeProvider>(
              builder: (context, provider, _) {
                return Column(
                  children: AppThemeId.values.map((id) {
                    final isSelected = provider.activeId == id;
                    final isLast = id == AppThemeId.values.last;

                    return Column(
                      children: [
                        _ThemeTile(
                          id: id,
                          isSelected: isSelected,
                          onTap: () => provider.setTheme(id),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 60,
                            color: cs.onSurface.withAlpha(18),
                          ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Conta',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.onSurface.withAlpha(18), width: 1),
            ),
            child: ListTile(
              leading: Icon(
                Icons.person_outline_rounded,
                color: cs.onSurfaceVariant,
              ),
              title: Text('Perfil', style: TextStyle(color: cs.onSurface)),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => Navigator.pushNamed(context, '/profile'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.id,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeId id;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  // Builds the widget tree for this view
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = ThemeProvider.labels[id] ?? id.name;
    final icon = ThemeProvider.icons[id] ?? Icons.palette_rounded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withAlpha(30)
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.onSurface.withAlpha(80),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
