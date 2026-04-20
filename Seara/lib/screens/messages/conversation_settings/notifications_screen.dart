import 'package:flutter/material.dart';
import 'package:seara/models/conversation_settings_model.dart';
import 'package:seara/services/conversation_settings_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.notification,
  });

  final int conversationId;
  final int userId;
  final ConversationNotification notification;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late bool _isMuted;
  late DateTime? _mutedUntil;
  bool _isSaving = false;

  @override
  // Initializes state used by this widget
  void initState() {
    super.initState();
    _isMuted = widget.notification.isEffectivelyMuted;
    _mutedUntil = widget.notification.mutedUntil;
  }

  Future<void> _updateMute({required bool muted, DateTime? until}) async {
    setState(() => _isSaving = true);
    try {
      await ConversationSettingsService.updateNotifications(
        widget.conversationId,
        widget.userId,
        isMuted: muted,
        mutedUntil: until?.toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _isMuted = muted;
        _mutedUntil = until;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            muted ? 'Conversa silenciada' : 'Notificações ativadas',
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

  // Shows duration picker
  void _showDurationPicker() {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final options = [
      _MuteOption('1 hora', now.add(const Duration(hours: 1))),
      _MuteOption('8 horas', now.add(const Duration(hours: 8))),
      _MuteOption('24 horas', now.add(const Duration(hours: 24))),
      _MuteOption('7 dias', now.add(const Duration(days: 7))),
      _MuteOption('Indefinidamente', null),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Silenciar durante',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...options.map(
                (opt) => ListTile(
                  title: Text(opt.label),
                  leading: const Icon(Icons.timer_outlined),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateMute(muted: true, until: opt.until);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  // Builds the widget tree for this view
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Notificações',
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
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(60),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isMuted
                            ? Icons.notifications_off_rounded
                            : Icons.notifications_active_rounded,
                        size: 32,
                        color: _isMuted
                            ? theme.colorScheme.onSurface.withAlpha(120)
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isMuted ? 'Silenciado' : 'Ativadas',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isMuted && _mutedUntil != null)
                              Text(
                                'Até ${_mutedUntil!.day}/${_mutedUntil!.month}/${_mutedUntil!.year} ${_mutedUntil!.hour}:${_mutedUntil!.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    120,
                                  ),
                                ),
                              ),
                            if (_isMuted && _mutedUntil == null)
                              Text(
                                'Indefinidamente',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    120,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_isMuted)
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Ativar notificações'),
                    onTap: () => _updateMute(muted: false),
                  ),
                if (!_isMuted)
                  ListTile(
                    leading: Icon(
                      Icons.notifications_off_rounded,
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                    title: const Text('Silenciar conversa'),
                    onTap: _showDurationPicker,
                  ),
                if (_isMuted)
                  ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                    title: const Text('Alterar duração'),
                    onTap: _showDurationPicker,
                  ),
              ],
            ),
    );
  }
}

class _MuteOption {
  final String label;
  final DateTime? until;
  const _MuteOption(this.label, this.until);
}
