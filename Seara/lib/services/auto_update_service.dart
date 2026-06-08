import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum UpdateStatus { upToDate, optionalUpdate, forcedUpdate }

class UpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String url;

  UpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.url,
  });
}

class AutoUpdateService {
  static const String currentVersion = "1.0.7";
  // Em produção, isto deve vir de um ficheiro de config ou env
  static const String baseUrl = "https://seara.onrender.com";

  /// Compara se [latest] é mais recente que [current]
  static bool isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts = current
          .split('.')
          .map((e) => int.parse(e.split('+')[0]))
          .toList();
      List<int> latestParts = latest
          .split('.')
          .map((e) => int.parse(e.split('+')[0]))
          .toList();

      for (int i = 0; i < 3; i++) {
        int curr = i < currentParts.length ? currentParts[i] : 0;
        int lat = i < latestParts.length ? latestParts[i] : 0;
        if (lat > curr) return true;
        if (lat < curr) return false;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<Map<String, dynamic>> checkUpdate() async {
    print("UPDATE CHECK STARTED");

    try {
      final response = await http
          .get(Uri.parse("$baseUrl/version"))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print("UPDATE RESPONSE: $data");
        print("CURRENT VERSION: $currentVersion");

        final latestVersion = data['latestVersion'] as String;
        final minVersion = data['minVersion'] as String;
        final url = data['url'] as String;

        if (isNewerVersion(currentVersion, minVersion)) {
          print("FORCED UPDATE DETECTED");
          return {
            'status': UpdateStatus.forcedUpdate,
            'info': UpdateInfo(
              latestVersion: latestVersion,
              minVersion: minVersion,
              url: url,
            ),
          };
        } else if (isNewerVersion(currentVersion, latestVersion)) {
          print("OPTIONAL UPDATE DETECTED");
          return {
            'status': UpdateStatus
                .optionalUpdate, // Aqui pode ser tratado como obrigatório na UI
            'info': UpdateInfo(
              latestVersion: latestVersion,
              minVersion: minVersion,
              url: url,
            ),
          };
        }
      }
    } catch (e) {
      stderr.writeln("Erro ao verificar atualização: $e");
    }
    print("NO UPDATE");
    return {'status': UpdateStatus.upToDate};
  }

  static Future<void> downloadAndInstall(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = p.join(tempDir.path, "SearaSetup.exe");
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Executar o instalador em modo silencioso
        await Process.start(filePath, [
          "/VERYSILENT",
          "/NORESTART",
          "/CLOSEAPPLICATIONS",
        ], mode: ProcessStartMode.detached);

        // Fechar a aplicação imediatamente
        exit(0);
      }
    } catch (e) {
      stderr.writeln("Erro ao descarregar ou instalar: $e");
    }
  }
}
