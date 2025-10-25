import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: Center(
        child: SwitchListTile(
          title: const Text('Modo escuro'),
          value: theme.isDarkMode,
          onChanged: (_) => theme.toggleTheme(),
        ),
      ),
    );
  }
}
