import 'package:flutter/material.dart';
import '../services/time_service.dart';

class DesyncErrorScreen extends StatelessWidget {
  const DesyncErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.update_disabled, size: 80, color: cs.error),
            const SizedBox(height: 24),
            Text(
              "Data/hora do dispositivo incorreta",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Ajusta o relógio do teu dispositivo para continuar. Uma discrepância grande de tempo impede o funcionamento seguro da app.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => TimeService.syncTime(),
              icon: const Icon(Icons.sync),
              label: const Text("Tentar Novamente"),
            ),
          ],
        ),
      ),
    ));
  }
}
