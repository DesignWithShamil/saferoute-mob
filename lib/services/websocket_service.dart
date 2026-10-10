import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config/env.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  int _retryCount = 0;
  bool _isConnected = false;

  final _storage = const FlutterSecureStorage();
  final Map<String, List<Function(Map<String, dynamic>)>> _listeners = {};

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_channel != null) return;
    
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    _intentionalClose = false;

    try {
      final wsUrl = '${Env.wsBaseUrl}/ws/events/?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _isConnected = true;
          _retryCount = 0;
          notifyListeners();
          
          try {
            final payload = jsonDecode(message);
            if (payload['event'] != null) {
              final eventName = payload['event'] as String;
              final data = payload['data'] as Map<String, dynamic>;
              _dispatch(eventName, data);
            }
          } catch (e) {
            debugPrint('[WebSocket] Parse error: $e');
          }
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('[WebSocket] Error: $error');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _channel = null;
    notifyListeners();

    if (!_intentionalClose) {
      final delay = (1000 * (1 << _retryCount)).clamp(1000, 15000);
      _retryCount++;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(milliseconds: delay), connect);
    }
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    notifyListeners();
  }

  void subscribe(String eventName, Function(Map<String, dynamic>) callback) {
    if (!_listeners.containsKey(eventName)) {
      _listeners[eventName] = [];
    }
    _listeners[eventName]!.add(callback);
  }

  void unsubscribe(String eventName, Function(Map<String, dynamic>) callback) {
    if (_listeners.containsKey(eventName)) {
      _listeners[eventName]!.remove(callback);
    }
  }

  void _dispatch(String eventName, Map<String, dynamic> data) {
    if (_listeners.containsKey(eventName)) {
      for (final callback in _listeners[eventName]!) {
        callback(data);
      }
    }
  }
}
