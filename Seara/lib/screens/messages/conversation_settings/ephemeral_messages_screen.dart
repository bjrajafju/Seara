import 'package:flutter/material.dart';
import 'package:seara/services/conversation_settings_service.dart';

class EphemeralMessagesScreen extends StatefulWidget {
  const EphemeralMessagesScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.currentDuration,
    required this.isAdmin,
  });

  final int conversationId;
  final int userId;
  final int currentDuration;
  final bool isAdmin;

  @override
  /// Creates the state object for this screen
  State<EphemeralMessagesScreen> createState() =>
      _EphemeralMessagesScreenState();
}

class _EphemeralMessagesScreenState extends State<EphemeralMessagesScreen> {
  late int _selected;
  bool _isSaving = false;

  static const _options = [
    _DurationOption(
      0,
      'Desativado',
      'Mensagens ficam permanentes',
      Icons.chat_bubble_outline_rounded,
    ),
    _DurationOption(
      1,
      '24 horas',
      'Mensagens desaparecem após 1 dia',
      Icons.looks_one_rounded,
    ),
    _DurationOption(
      2,
      '7 dias',
      'Mensagens desaparecem após 1 semana',
      Icons.date_range_rounded,
    ),
    _DurationOption(
      3,
      '30 dias',
      'Mensagens desaparecem após 1 mês',
      Icons.calendar_month_rounded,
    ),
  ];

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _selected = widget.currentDuration;
  }

  /// Save
  Future<void> _save(int duration) async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apenas admins podem alterar esta definição.'),
        ),
      );
      return;
    }

    setState(() {
      _selected = duration;
      _isSaving = true;
    });

    try {
      await ConversationSettingsService.updateSettings(
        widget.conversationId,
        widget.userId,
        {'ephemeral_duration': duration},
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            duration == 0
                ? 'Mensagens temporárias desativadas'
                : 'Mensagens temporárias ativadas',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  @override
  /// Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Mensagens temporárias',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Quando ativadas, novas mensagens desaparecerão após o tempo selecionado. Mensagens existentes não são afetadas.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._options.map((opt) {
                  final isSelected = _selected == opt.value;
                  return ListTile(
                    leading: Icon(
                      opt.icon,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withAlpha(100),
                    ),
                    title: Text(
                      opt.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      opt.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(100),
                      ),
                    ),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withAlpha(100),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    onTap: () => _save(opt.value),
                  );
                }),
              ],
            ),
    );
  }
}

class _DurationOption {
  final int value;
  final String title;
  final String subtitle;
  final IconData icon;
  const _DurationOption(this.value, this.title, this.subtitle, this.icon);
}
