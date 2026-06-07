import 'package:http/http.dart' as http;
export 'package:http/http.dart' show Response, MultipartRequest, MultipartFile;
import 'dart:async';
import 'dart:collection';
import 'auth_service.dart';

class ApiClient {
  static final Map<String, _EndpointState> _states = {};
  static final Set<String> _pendingRequests = {};
  
  static const int _maxRetries = 2;
  static const int _circuitBreakerThreshold = 5;
  static const Duration _circuitBreakerDuration = Duration(seconds: 30);

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

  static String _getEndpointKey(Uri url) {
    return "${url.origin}${url.path}";
  }

  static Future<http.Response> _requestWithGuard(
    Future<http.Response> Function() requestFn,
    Uri url,
  ) async {
    final key = _getEndpointKey(url);
    final state = _states.putIfAbsent(key, () => _EndpointState());

    // Circuit Breaker check
    if (state.blockedUntil != null && DateTime.now().isBefore(state.blockedUntil!)) {
      throw Exception('Circuit breaker active for $key. Try again later.');
    }

    // Duplicate request check (simple lock)
    if (_pendingRequests.contains(key)) {
      if (kDebugMode) {
        print('Blocking duplicate request to $key');
      }
      // Optional: wait or return previous future. For now, we block to prevent loop.
      throw Exception('Request to $key is already in progress.');
    }
    _pendingRequests.add(key);

    try {
      int attempts = 0;
      while (attempts <= _maxRetries) {
        try {
          final response = await requestFn();
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            state.reset();
            return response;
          }

          if (kDebugMode) {
            print('API Error: ${response.statusCode} for $key');
          }

          if (response.statusCode == 401 || response.statusCode == 403) {
            // Sincroniza tempo em caso de erro de auth, pois pode ser desync
            await TimeService.syncTime();
          }

          if (response.statusCode == 429 || response.statusCode >= 500) {
            attempts++;
            if (attempts <= _maxRetries) {
              final backoff = Duration(seconds: attempts * 2);
              await Future.delayed(backoff);
              continue;
            }
          }
          
          _handleFailure(state, key);
          return response;
        } catch (e) {
          attempts++;
          if (attempts <= _maxRetries) {
            final backoff = Duration(seconds: attempts * 2);
            await Future.delayed(backoff);
            continue;
          }
          _handleFailure(state, key);
          rethrow;
        }
      }
      throw Exception('Max retries reached for $key');
    } finally {
      _pendingRequests.remove(key);
    }
  }

  static void _handleFailure(_EndpointState state, String key) {
    state.failureCount++;
    if (state.failureCount >= _circuitBreakerThreshold) {
      state.blockedUntil = DateTime.now().add(_circuitBreakerDuration);
    }
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return _requestWithGuard(() async {
      final modifiedHeaders = await _attachAuth(headers);
      return await http.get(url, headers: modifiedHeaders);
    }, url);
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _requestWithGuard(() async {
      final modifiedHeaders = await _attachAuth(headers);
      return await http.post(url, headers: modifiedHeaders, body: body);
    }, url);
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _requestWithGuard(() async {
      final modifiedHeaders = await _attachAuth(headers);
      return await http.put(url, headers: modifiedHeaders, body: body);
    }, url);
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _requestWithGuard(() async {
      final modifiedHeaders = await _attachAuth(headers);
      return await http.delete(url, headers: modifiedHeaders, body: body);
    }, url);
  }

  static Future<Map<String, String>> attachAuthHeaders(
    Map<String, String>? customHeaders,
  ) async {
    return _attachAuth(customHeaders);
  }
}

class _EndpointState {
  int failureCount = 0;
  DateTime? blockedUntil;

  void reset() {
    failureCount = 0;
    blockedUntil = null;
  }
}
