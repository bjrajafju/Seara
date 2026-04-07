import 'package:flutter/material.dart';
import 'package:seara/services/conversation_settings_service.dart';

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

  static const _themes = [
    _ThemeOption(0, 'Padrão', [Color(0xFF1C1C1E), Color(0xFF2C2C2E)]),
    _ThemeOption(1, 'Oceano', [Color(0xFF0D1B2A), Color(0xFF1B3A4B)]),
    _ThemeOption(2, 'Pôr do Sol', [Color(0xFF2D1B69), Color(0xFF862F58)]),
    _ThemeOption(3, 'Floresta', [Color(0xFF0B3D2C), Color(0xFF1A5C3A)]),
    _ThemeOption(4, 'Meia-noite', [Color(0xFF0A0A1A), Color(0xFF1A1A3A)]),
  ];

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
          content: Text('Tema alterado para ${_themes[theme].name}'),
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
              itemCount: _themes.length,
              itemBuilder: (context, index) {
                final t = _themes[index];
                final isSelected = _selectedTheme == t.id;

                return GestureDetector(
                  onTap: () => _save(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: t.colors,
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
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Olá! 👋',
                              style: TextStyle(
                                color: Colors.white70,
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
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Tudo bem? 😊',
                              style: TextStyle(
                                color: Colors.white70,
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
                            style: const TextStyle(
                              color: Colors.white,
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

class _ThemeOption {
  final int id;
  final String name;
  final List<Color> colors;
  const _ThemeOption(this.id, this.name, this.colors);
}
