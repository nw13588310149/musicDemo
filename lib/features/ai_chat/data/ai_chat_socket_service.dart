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
    final hasStringContent = json['content'] is String;
    if (!hasStringContent) {
      return false;
    }

    // 流式增量帧典型形态：type ∈ {1, 10014}，content 为字符串。
    //
    // 历史教训：
    // 1) 旧版要求 `sessionId == null && role == null`，但服务端在「新建会话
    //    首条回复」上每片都带 sessionId，结果首轮整帧被误判到 full 分支后立刻
    //    `_finishAiStream`，后续增量被丢弃 → 表现为「没有打字效果」。
    // 2) 改成「必须带 replyId」之后，仍然有部分场景（首条回复、断线重连后的
    //    第一片、deepseek 流的中段恢复包）服务端不下发 replyId，分片再次落入
    //    full 分支，又出现「结束时一次渲染」。
    //
    // 因此这里采用最宽松、最符合 web 1.0 实际行为的规则：
    // - type == 1：DeepSeek/小艺同学常规流式增量 type，**只要 content 是字符串
    //   就当作流式分片**，不管 replyId 是否存在；
    // - type == 10014：协议里同时承担「流式分片」与「最终 envelope」两种语义，
    //   为了避免把 envelope 全量帧也当成 delta 累加，这里仍要求带 replyId。
    if (type == 1) {
      return true;
    }
    return json['replyId'] != null;
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
