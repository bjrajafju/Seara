import 'package:flutter/material.dart';
import 'package:seara/models/conversation_settings_model.dart';
import 'package:seara/services/conversation_settings_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.settings,
  });

  final int conversationId;
  final int userId;
  final ConversationSettings settings;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late int _whoCanManageMembers;
  late int _whoCanEditInfo;
  late int _whoCanSendMessages;
  late int _whoCanEditBio;
  bool _isSaving = false;

  @override
  /// Initializes state used by this widget
  void initState() {
    super.initState();
    _whoCanManageMembers = widget.settings.whoCanManageMembers;
    _whoCanEditInfo = widget.settings.whoCanEditInfo;
    _whoCanSendMessages = widget.settings.whoCanSendMessages;
    _whoCanEditBio = widget.settings.whoCanEditBio;
  }

  /// Save
  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ConversationSettingsService.updateSettings(
        widget.conversationId,
        widget.userId,
        {
          'who_can_manage_members': _whoCanManageMembers,
          'who_can_edit_info': _whoCanEditInfo,
          'who_can_send_messages': _whoCanSendMessages,
          'who_can_edit_bio': _whoCanEditBio,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissões atualizadas'),
          duration: Duration(seconds: 1),
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
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Administração',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
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
                    Icons.admin_panel_settings_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Configura quem pode fazer o quê neste grupo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildPermissionRow(
            theme,
            icon: Icons.group_add_rounded,
            title: 'Gerir membros',
            subtitle: 'Quem pode adicionar e remover membros',
            value: _whoCanManageMembers,
            onChanged: (val) => setState(() => _whoCanManageMembers = val),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          _buildPermissionRow(
            theme,
            icon: Icons.edit_rounded,
            title: 'Editar nome e imagem',
            subtitle: 'Quem pode alterar informações do grupo',
            value: _whoCanEditInfo,
            onChanged: (val) => setState(() => _whoCanEditInfo = val),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          _buildPermissionRow(
            theme,
            icon: Icons.message_rounded,
            title: 'Enviar mensagens',
            subtitle:
                'Quem pode enviar mensagens (modo anúncio se apenas admins)',
            value: _whoCanSendMessages,
            onChanged: (val) => setState(() => _whoCanSendMessages = val),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          _buildPermissionRow(
            theme,
            icon: Icons.description_rounded,
            title: 'Editar descrição',
            subtitle: 'Quem pode alterar a descrição do grupo',
            value: _whoCanEditBio,
            onChanged: (val) => setState(() => _whoCanEditBio = val),
          ),

          if (_whoCanSendMessages == 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.tertiary.withAlpha(160)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: cs.tertiary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modo anúncio ativado — apenas admins podem enviar mensagens.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Todos')),
                    ButtonSegment(value: 1, label: Text('Admins')),
                  ],
                  selected: {value},
                  onSelectionChanged: (val) => onChanged(val.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: theme.colorScheme.primary
                        .withAlpha(30),
                    selectedForegroundColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
