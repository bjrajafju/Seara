import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

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
  static const String currentVersion = "3.0.0";
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
          .get(Uri.parse("$baseUrl/version?platform=${platform}"))
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
      final stopwatch = Stopwatch()..start();

      print("DOWNLOAD START: $url");

      final response = await http.get(Uri.parse(url));

      stopwatch.stop();

      print("DOWNLOAD FINISHED");
      print("DOWNLOAD TIME: ${stopwatch.elapsed.inSeconds}s");
      print("STATUS CODE: ${response.statusCode}");
      print("BYTES: ${response.bodyBytes.length}");

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();

        print("TEMP DIR: ${tempDir.path}");

        final fileName = Platform.isAndroid ? "Seara.apk" : "SearaSetup.exe";
        final filePath = p.join(tempDir.path, fileName);

        print("WRITING FILE: $filePath");

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print("FILE WRITTEN");

        if (Platform.isAndroid) {
          print("STARTING APK INSTALL...");

          await installApk(filePath);

          await Future.delayed(const Duration(seconds: 3));
        } else {
          await Process.start(filePath, [
            "/VERYSILENT",
            "/NORESTART",
            "/CLOSEAPPLICATIONS",
          ], mode: ProcessStartMode.detached);
        }
      }
    } catch (e) {
      stderr.writeln("Erro ao descarregar ou instalar: $e");
      print("DOWNLOAD ERROR: $e");
    }
  }

  static Future<void> installApk(String path) async {
    if (!Platform.isAndroid) return;

    print("INSTALL APK START");
    print("APK PATH: $path");

    final status = await Permission.requestInstallPackages.status;
    print("CURRENT PERMISSION STATUS: $status");

    if (!status.isGranted) {
      print("REQUESTING PERMISSION...");

      final result = await Permission.requestInstallPackages.request();
      print("PERMISSION RESULT: $result");

      if (!result.isGranted) {
        print("PERMISSION DENIED -> OPEN SETTINGS");
        await openAppSettings();
        return;
      }
    }

    print("OPENING APK INSTALLER...");
    final result = await OpenFilex.open(path);

    print("INSTALL RESULT TYPE: ${result.type}");
    print("INSTALL RESULT MESSAGE: ${result.message}");
  }

  static String get platform {
    if (kIsWeb) return "web";
    if (defaultTargetPlatform == TargetPlatform.android) return "android";
    if (defaultTargetPlatform == TargetPlatform.windows) return "windows";
    return "windows";
  }
}
