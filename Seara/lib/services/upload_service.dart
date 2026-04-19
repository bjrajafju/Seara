import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
      http.MultipartFile.fromBytes("file", fileBytes, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return UploadResult(
        url: data["url"] as String,
        contentType: data["content_type"] as String? ?? mimeType,
        fileName: data["file_name"] as String? ?? fileName,
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error["error"] ?? "Erro ao fazer upload.");
    }
  }
}
