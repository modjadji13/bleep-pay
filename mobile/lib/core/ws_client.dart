import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../state/auth_provider.dart';
import 'api_client.dart';

enum WsEventType {
  paymentRequest,
  paymentCompleted,
  paymentDeclined,
  unknown,
}

class WsEvent {
  final WsEventType type;
  final Map<String, dynamic> data;

  const WsEvent({required this.type, required this.data});
}

class WsClient {
  final String token;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _closedByUser = false;

  void Function(WsEvent event)? onEvent;

  WsClient({required this.token});

  void connect() {
    _closedByUser = false;
    _connectInternal();
  }

  void _connectInternal() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('${baseUrl.replaceFirst('http', 'ws')}/ws?token=$token'));
      _channel!.stream.listen(
        (message) {
          final parsed = _parseEvent(message);
          if (parsed != null) onEvent?.call(parsed);
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closedByUser) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _connectInternal);
  }

  WsEvent? _parseEvent(dynamic message) {
    try {
      final data = Map<String, dynamic>.from(jsonDecode(message as String) as Map);
      final eventName = data['event'] as String?;
      final type = switch (eventName) {
        'payment_request' => WsEventType.paymentRequest,
        'payment_completed' => WsEventType.paymentCompleted,
        'payment_declined' => WsEventType.paymentDeclined,
        _ => WsEventType.unknown,
      };
      return WsEvent(type: type, data: data);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }
}

final wsClientProvider = Provider<WsClient?>((ref) {
  final auth = ref.watch(authProvider);
  final token = auth.token;
  if (token == null) return null;

  final client = WsClient(token: token);
  client.connect();
  ref.onDispose(client.dispose);
  return client;
});
