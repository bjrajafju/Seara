import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UploadService {
  static const String baseUrl = "http://localhost:3000";

  static Future<String> uploadImage({
    required String bucket,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final uri = Uri.parse("$baseUrl/upload/$bucket");
    final request = http.MultipartRequest("POST", uri);

    request.files.add(
      http.MultipartFile.fromBytes("file", fileBytes, filename: fileName),
    );

    // Definir Content-Type do ficheiro
    request.files.last;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data["url"] as String;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error["error"] ?? "Erro ao fazer upload.");
    }
  }
}
