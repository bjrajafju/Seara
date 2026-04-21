import 'dart:convert';
import 'package:seara/config/api_config.dart';
import 'package:seara/services/api_client.dart';
import '../models/link_preview_model.dart';

class LinkPreviewService {
  static String get baseUrl => "${ApiConfig.baseUrl}/messages";

  static final Map<String, LinkPreview?> _cache = {};

  /// Fetches metadata used in link previews
  static Future<LinkPreview?> fetchLinkPreview(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      final uri = Uri.parse(
        "$baseUrl/link-preview",
      ).replace(queryParameters: {'url': url});

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
    } catch (_) {}

    _cache[url] = null;
    return null;
  }
}
