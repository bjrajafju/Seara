import 'package:flutter/material.dart';
import '../services/auto_update_service.dart';

class UpdateScreen extends StatefulWidget {
  final UpdateInfo updateInfo;
  final bool isForced;

  const UpdateScreen({
    super.key,
    required this.updateInfo,
    required this.isForced,
  });

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _isDownloading = false;

  void _handleUpdate() async {
    setState(() {
      _isDownloading = true;
    });
    await AutoUpdateService.downloadAndInstall(widget.updateInfo.url);
    // Aplicação fecha-se dentro do downloadAndInstall
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.system_update_rounded,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              widget.isForced ? "Atualização obrigatória" : "Nova atualização disponível",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Uma nova versão (${widget.updateInfo.latestVersion}) está disponível.\nPor favor, atualize para continuar a utilizar a aplicação.",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_isDownloading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("A descarregar atualização..."),
                ],
              )
            else
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Atualizar agora",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
