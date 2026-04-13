import 'dart:convert';
import 'package:seara/services/api_client.dart';
import '../models/link_preview_model.dart';

class LinkPreviewService {
  static const String baseUrl = "http://localhost:3000/messages";

  // Simple in-memory cache to avoid duplicate requests for the same URL
  static final Map<String, LinkPreview?> _cache = {};

  static Future<LinkPreview?> fetchLinkPreview(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      final uri = Uri.parse("$baseUrl/link-preview").replace(
        queryParameters: {'url': url},
      );

      final response = await ApiClient.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) {
          _cache[url] = null;
          return null;
        }

        final preview = LinkPreview.fromJson(data);
        if (preview.isEmpty) {
          _cache[url] = null;
          return null;
        }

        _cache[url] = preview;
        return preview;
      }
    } catch (_) {
      // Ignore errors silently as requested
    }

    _cache[url] = null;
    return null;
  }
}
