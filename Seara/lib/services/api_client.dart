import 'package:http/http.dart' as http;
export 'package:http/http.dart' show Response, MultipartRequest, MultipartFile;
import 'auth_service.dart';

class ApiClient {
  static Future<Map<String, String>> _attachAuth(
    Map<String, String>? customHeaders,
  ) async {
    final token = await AuthService.getToken();
    final modified = customHeaders != null
        ? Map<String, String>.from(customHeaders)
        : <String, String>{};
    if (token != null) {
      modified['Authorization'] = 'Bearer $token';
    }
    return modified;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final modifiedHeaders = await _attachAuth(headers);
    return await http.get(url, headers: modifiedHeaders);
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final modifiedHeaders = await _attachAuth(headers);
    return await http.post(url, headers: modifiedHeaders, body: body);
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final modifiedHeaders = await _attachAuth(headers);
    return await http.put(url, headers: modifiedHeaders, body: body);
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final modifiedHeaders = await _attachAuth(headers);
    return await http.delete(url, headers: modifiedHeaders, body: body);
  }

  static Future<Map<String, String>> attachAuthHeaders(
    Map<String, String>? customHeaders,
  ) async {
    return _attachAuth(customHeaders);
  }
}
