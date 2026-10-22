import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart' as pusher_transport;
import '../core/config/env.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef PusherTransport = pusher_transport.WebSocketChannel;

class PusherService extends ChangeNotifier {
  static const String pusherKey = '499b65a2edb800976596';
  static const String pusherCluster = 'ap2';

  PusherTransport? _transport;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  int _retryCount = 0;
  bool _isConnected = false;
  final Set<String> _subscribedChannels = {};

  final _storage = const FlutterSecureStorage();
  final Map<String, List<Function(Map<String, dynamic>)>> _listeners = {};
  final Set<String> _seenEventIds = {};

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_transport != null) return;

    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    _intentionalClose = false;

    // Fetch user channels from backend
    List<String> channels = [];
    String key = pusherKey;
    String cluster = pusherCluster;

    try {
      final dio = Dio();
      final res = await dio.get(
        '${Env.apiBaseUrl}/notifications/channels/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (res.data is Map && res.data['data'] is Map) {
        final d = res.data['data'] as Map<String, dynamic>;
        key = d['key'] ?? key;
        cluster = d['cluster'] ?? cluster;
        if (d['channels'] is List) {
          channels = List<String>.from(d['channels'] as List);
        }
      }
    } catch (e) {
      debugPrint('[Pusher] Could not fetch channels, using defaults: $e');
    }

    if (_intentionalClose) return;

    try {
      final pusherUrl = 'wss://ws-$cluster.pusher.com:443/app/$key?protocol=7&client=dart&version=1.0.0';
      _transport = pusher_transport.WebSocketChannel.connect(Uri.parse(pusherUrl));

      _transport!.stream.listen(
        (message) {
          try {
            final payload = jsonDecode(message.toString());
            if (payload is! Map) return;

            final event = payload['event'] as String?;
            if (event == null) return;

            // Handle connection
            if (event == 'pusher:connection_established') {
              _isConnected = true;
              _retryCount = 0;
              notifyListeners();
              debugPrint('[Pusher] Connected successfully');

              // Subscribe to all authorized channels
              for (final ch in channels) {
                subscribeChannel(ch);
              }
              return;
            }

            // Handle ping/pong keepalive
            if (event == 'pusher:ping') {
              _transport?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
              return;
            }

            // Ignore pusher internal events
            if (event.startsWith('pusher:') || event.startsWith('pusher_internal:')) {
              return;
            }

            // Unpack data
            dynamic dataRaw = payload['data'];
            Map<String, dynamic> dataMap = {};
            if (dataRaw is String) {
              try {
                final decoded = jsonDecode(dataRaw);
                if (decoded is Map) {
                  dataMap = Map<String, dynamic>.from(decoded);
                }
              } catch (_) {}
            } else if (dataRaw is Map) {
              dataMap = Map<String, dynamic>.from(dataRaw);
            }

            final eventId = dataMap['event_id'] as String?;
            if (eventId != null) {
              if (_seenEventIds.contains(eventId)) return;
              _seenEventIds.add(eventId);
              if (_seenEventIds.length > 300) {
                _seenEventIds.remove(_seenEventIds.first);
              }
            }

            final actualData = dataMap['data'] is Map
                ? Map<String, dynamic>.from(dataMap['data'] as Map)
                : dataMap;

            _dispatch(event, actualData);
          } catch (e) {
            debugPrint('[Pusher] Parse error: $e');
          }
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('[Pusher] Error: $error');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[Pusher] Connection failed: $e');
      _handleDisconnect();
    }
  }

  void subscribeChannel(String channelName) {
    if (_transport == null || _subscribedChannels.contains(channelName)) return;
    _subscribedChannels.add(channelName);
    _transport?.sink.add(jsonEncode({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName}
    }));
  }

  void unsubscribeChannel(String channelName) {
    if (_transport == null || !_subscribedChannels.contains(channelName)) return;
    _subscribedChannels.remove(channelName);
    _transport?.sink.add(jsonEncode({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName}
    }));
  }

  void _handleDisconnect() {
    _isConnected = false;
    _transport = null;
    _subscribedChannels.clear();
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
    _subscribedChannels.clear();
    if (_transport != null) {
      _transport!.sink.close();
      _transport = null;
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
