import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';

final aiChatSocketServiceProvider = Provider<AiChatSocketService>((ref) {
  final storage = ref.watch(appStorageProvider);
  final service = AiChatSocketService(storage: storage);
  ref.onDispose(service.dispose);
  return service;
});

enum AiChatSocketEventType { stream, full, message }

class AiChatSocketEvent {
  const AiChatSocketEvent({required this.type, required this.payload});

  final AiChatSocketEventType type;
  final Map<String, dynamic> payload;
}

class AiChatSocketService {
  AiChatSocketService({required AppStorage storage}) : _storage = storage;

  final AppStorage _storage;
  final StreamController<AiChatSocketEvent> _events =
      StreamController<AiChatSocketEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionallyClosed = false;

  Stream<AiChatSocketEvent> get events => _events.stream;

  void connect() {
    if (_disposed) {
      return;
    }
    final token = _storage.token;
    if (token.isEmpty) {
      return;
    }

    _intentionallyClosed = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeChannel();

    try {
      final channel = WebSocketChannel.connect(_wsUri());
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onError: (_) => _handleClosed(),
        onDone: _handleClosed,
        cancelOnError: true,
      );
      channel.sink.add(
        jsonEncode(<String, dynamic>{'type': 1000, 'token': token}),
      );
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void dispose() {
    _disposed = true;
    _intentionallyClosed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _closeChannel();
    unawaited(_events.close());
  }

  Uri _wsUri() {
    final base = AppConstants.apiBaseUrl.trim();
    if (base.startsWith('https://')) {
      return Uri.parse(
        'wss://${base.substring('https://'.length).replaceFirst(RegExp(r'/$'), '')}/websocket',
      );
    }
    if (base.startsWith('http://')) {
      return Uri.parse(
        'ws://${base.substring('http://'.length).replaceFirst(RegExp(r'/$'), '')}/websocket',
      );
    }
    return Uri.parse('$base/websocket');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      try {
        _channel?.sink.add(jsonEncode(<String, dynamic>{'type': 100}));
      } catch (_) {
        _handleClosed();
      }
    });
  }

  void _handleRawMessage(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(text);
      final map = _toMap(decoded);
      if (map == null) {
        return;
      }
      _emit(AiChatSocketEventType.message, map);
      final normalizedType = _normalizeWsType(map);
      if (normalizedType == 0 ||
          normalizedType == 10004 ||
          normalizedType == 10013 ||
          _isLikelyChatGptStreamChunk(map, normalizedType)) {
        _emit(AiChatSocketEventType.stream, map);
      } else if (normalizedType == 1 ||
          normalizedType == 10005 ||
          normalizedType == 10014 ||
          _isAssistantFullPayload(map, normalizedType)) {
        _emit(AiChatSocketEventType.full, map);
      }
    } catch (_) {
      return;
    }
  }

  void _emit(AiChatSocketEventType type, Map<String, dynamic> payload) {
    if (!_events.isClosed) {
      _events.add(AiChatSocketEvent(type: type, payload: payload));
    }
  }

  int? _normalizeWsType(Map<String, dynamic> json) {
    final value = json['type'] ?? json['msgType'] ?? json['messageType'];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  bool _isLikelyChatGptStreamChunk(Map<String, dynamic> json, int? type) {
    if (type != 1 && type != 10014) {
      return false;
    }
    return json['content'] is String &&
        json['replyId'] != null &&
        json['role'] == null &&
        json['sessionId'] == null &&
        json['chatSessionId'] == null;
  }

  bool _isAssistantFullPayload(Map<String, dynamic> json, int? type) {
    if (type != null) {
      return false;
    }
    return (json['role'] == 'assistant' || json['role'] == 'ai') &&
        json['content'] != null &&
        (json['sessionId'] != null || json['chatSessionId'] != null);
  }

  void _handleClosed() {
    if (_disposed || _intentionallyClosed) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _closeChannel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionallyClosed || _reconnectTimer != null) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      connect();
    });
  }

  void _closeChannel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // Ignore socket close errors.
    }
    _channel = null;
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, data) => MapEntry('$key', data));
    }
    return null;
  }
}
