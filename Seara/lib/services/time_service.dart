import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TimeService {
  static DateTime? _serverTime;
  static DateTime? _localTimeAtSync;
  static String? _serverDate;
  static DateTime? _lastSync;
  
  static final _desyncController = StreamController<bool>.broadcast();
  static bool _hasCriticalDesync = false;

  static Stream<bool> get desyncStream => _desyncController.stream;
  static bool get hasCriticalDesync => _hasCriticalDesync;

  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Obtém a data atual do servidor no formato YYYY-MM-DD
  static String get serverDate => _serverDate ?? DateTime.now().toIso8601String().split('T')[0];

  /// Obtém o tempo atual sincronizado com o servidor
  static DateTime get now {
    if (_serverTime == null || _localTimeAtSync == null) {
      return DateTime.now();
    }
    final delta = DateTime.now().difference(_localTimeAtSync!);
    return _serverTime!.add(delta);
  }

  /// Sincroniza o tempo com o servidor
  static Future<void> syncTime() async {
    try {
      if (_lastSync != null && DateTime.now().difference(_lastSync!) < _cacheTtl) {
        return;
      }

      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/time'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _serverTime = DateTime.parse(data['serverTime']);
        _serverDate = data['serverDate'];
        _localTimeAtSync = DateTime.now();
        _lastSync = DateTime.now();
        
        if (kDebugMode) {
          print('Time synced: Server=$_serverTime, Local=$_localTimeAtSync, Date=$_serverDate');
        }
        
        _validateDesync();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync time: $e');
      }
    }
  }

  /// Valida se há um desequilíbrio suspeito entre o tempo local e do servidor
  static void _validateDesync() {
    if (_serverTime == null || _localTimeAtSync == null) return;
    
    final difference = _serverTime!.difference(_localTimeAtSync!).abs();
    
    // Se a diferença for maior que 2 dias, algo está muito errado
    final isCritical = difference > const Duration(days: 2);
    
    if (isCritical != _hasCriticalDesync) {
      _hasCriticalDesync = isCritical;
      _desyncController.add(isCritical);
    }

    if (isCritical && kDebugMode) {
      print('CRITICAL DESYNC DETECTED: $difference');
    }
  }
}
