import 'package:flutter/material.dart';
import 'package:seara/services/conversation_settings_service.dart';
import 'package:seara/utils/conversation_theme_helper.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.currentTheme,
    required this.isAdmin,
  });

  final int conversationId;
  final int userId;
  final int currentTheme;
  final bool isAdmin;

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  late int _selectedTheme;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  Future<void> _save(int theme) async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas admins podem alterar o tema.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedTheme = theme;
      _isSaving = true;
    });

    try {
      await ConversationSettingsService.updateSettings(
        widget.conversationId,
        widget.userId,
        {'theme': theme},
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema alterado para ${ConversationThemeHelper.getTheme(theme).name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Tema da conversa',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: ConversationThemeHelper.themes.length,
              itemBuilder: (context, index) {
                final t = ConversationThemeHelper.themes[index];
                final isSelected = _selectedTheme == t.id;

                return GestureDetector(
                  onTap: () => _save(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: t.backgroundColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    theme.colorScheme.primary.withAlpha(60),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Chat preview bubbles
                        Positioned(
                          left: 12,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  t.otherBubbleColor ??
                                  cs.surfaceContainerHighest.withAlpha(200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Olá! 👋',
                              style: TextStyle(
                                color:
                                    t.otherTextColor ??
                                    cs.onSurface.withAlpha(200),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  t.myBubbleColor ??
                                  cs.surfaceContainerHighest.withAlpha(220),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Tudo bem? 😊',
                              style: TextStyle(
                                color:
                                    t.myTextColor ?? cs.onSurface.withAlpha(200),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        // Theme name
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Text(
                            t.name,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Checkmark
                        if (isSelected)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
