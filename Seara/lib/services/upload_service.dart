import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:seara/config/api_config.dart';

import 'package:seara/services/api_client.dart';

class UploadResult {
  final String url;
  final String contentType;
  final String fileName;

  UploadResult({
    required this.url,
    required this.contentType,
    required this.fileName,
  });
}

class UploadService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<UploadResult> uploadFile({
    required String bucket,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final uri = Uri.parse("$baseUrl/upload/$bucket");
    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(await ApiClient.attachAuthHeaders(null));

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return UploadResult(
        url: data["url"] as String,
        contentType: data["content_type"] as String? ?? mimeType,
        fileName: data["file_name"] as String? ?? fileName,
      );
    } else {
      debugPrint(
        'UploadService: Upload failed with HTTP status code: ${response.statusCode}',
      );
      debugPrint('UploadService: Response body: ${response.body}');

      String errorMessage = "Erro ao fazer upload.";
      try {
        final error = jsonDecode(response.body);
        if (error is Map && error.containsKey("error")) {
          errorMessage = error["error"].toString();
        }
      } catch (_) {
        errorMessage = "Erro ${response.statusCode}: ${response.body}";
      }

      throw Exception(errorMessage);
    }
  }
}
