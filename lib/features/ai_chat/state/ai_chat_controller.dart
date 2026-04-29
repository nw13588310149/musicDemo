import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_chat_repository.dart';
import 'ai_chat_state.dart';

final aiChatControllerProvider =
    StateNotifierProvider.autoDispose<AiChatController, AiChatState>((ref) {
      final repository = ref.watch(aiChatRepositoryProvider);
      return AiChatController(repository: repository);
    });

class AiChatController extends StateNotifier<AiChatState> {
  AiChatController({required AiChatRepository repository})
    : _repository = repository,
      super(const AiChatState()) {
    unawaited(_loadInitial());
  }

  final AiChatRepository _repository;

  static const String _chatRobot = 'deepseek';

  Future<void> _loadInitial() async {
    await loadSessions(autoSelectFirst: false);
  }

  void toggleSidebar() {
    state = state.copyWith(sidebarCollapsed: !state.sidebarCollapsed);
  }

  void toggleDeepThinking() {
    state = state.copyWith(isDeepThinking: !state.isDeepThinking);
  }

  void toggleWebSearching() {
    state = state.copyWith(isWebSearching: !state.isWebSearching);
  }

  void toggleReasoningExpanded(String messageId) {
    final next = state.messages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      return message.copyWith(reasoningExpanded: !message.reasoningExpanded);
    }).toList();
    state = state.copyWith(messages: next);
  }

  Future<String?> loadSessions({bool autoSelectFirst = false}) async {
    state = state.copyWith(sessionsLoading: true);
    try {
      final response = await _repository.getSessionList(robot: _chatRobot);
      if (!response.isSuccess) {
        state = state.copyWith(sessionsLoading: false);
        return response.msg.isEmpty ? '加载会话列表失败' : response.msg;
      }

      final sessions = _normalizeSessionList(response.data);
      final sorted = _sortSessions(sessions);
      final activeExists = sorted.any(
        (item) => item.id == state.activeSessionId,
      );
      state = state.copyWith(
        sessionsLoading: false,
        sessions: sorted,
        activeSessionId: activeExists ? state.activeSessionId : null,
        clearActiveSessionId: !activeExists && state.activeSessionId != null,
      );

      if (autoSelectFirst &&
          state.activeSessionId == null &&
          sorted.isNotEmpty) {
        return selectSession(sorted.first.id);
      }
      return null;
    } catch (_) {
      state = state.copyWith(sessionsLoading: false);
      return '加载会话列表失败';
    }
  }

  Future<String?> selectSession(String sessionId) async {
    state = state.copyWith(activeSessionId: sessionId, waitingAssistant: false);
    return _fetchMessages(sessionId, showLoading: true);
  }

  void startNewChat() {
    state = state.copyWith(
      clearActiveSessionId: true,
      messages: const [],
      isNewConversation: true,
      waitingAssistant: false,
      sending: false,
      messagesLoading: false,
    );
  }

  Future<String?> deleteSession(AiChatSession session) async {
    try {
      final response = await _repository.deleteSession(session.id);
      if (!response.isSuccess) {
        return response.msg.isEmpty ? '删除会话失败' : response.msg;
      }

      final nextSessions = state.sessions
          .where((item) => item.id != session.id)
          .toList();

      if (state.activeSessionId == session.id) {
        state = state.copyWith(
          sessions: nextSessions,
          clearActiveSessionId: true,
          messages: const [],
          isNewConversation: true,
          waitingAssistant: false,
          sending: false,
        );
        return null;
      }

      state = state.copyWith(sessions: nextSessions);
      return null;
    } catch (_) {
      return '删除会话失败';
    }
  }

  Future<String?> sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.sending) {
      return null;
    }

    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pendingMessage = AiChatMessage(
      id: pendingId,
      type: AiChatMessageType.user,
      text: text,
      status: AiChatMessageStatus.sending,
      sortTime: DateTime.now(),
    );
    final previousAiCount = state.messages
        .where((item) => item.type == AiChatMessageType.ai)
        .length;

    state = state.copyWith(
      isNewConversation: false,
      waitingAssistant: true,
      sending: true,
      messages: [...state.messages, pendingMessage],
    );

    try {
      var sessionId = state.activeSessionId;
      if (sessionId == null) {
        final title = _titleFromFirstUserMessage(text);
        final createResponse = await _repository.createSession(
          title: title,
          robot: _chatRobot,
        );
        if (!createResponse.isSuccess) {
          _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
          state = state.copyWith(waitingAssistant: false, sending: false);
          return createResponse.msg.isEmpty ? '创建会话失败' : createResponse.msg;
        }

        final createdSessionId = _extractSessionId(createResponse.data);
        if (createdSessionId == null) {
          _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
          state = state.copyWith(waitingAssistant: false, sending: false);
          return '创建会话失败，未返回会话 ID';
        }

        sessionId = createdSessionId;
        final createdSession = AiChatSession(
          id: sessionId,
          title: title,
          sortTime: DateTime.now(),
        );
        final nextSessions = _sortSessions([
          createdSession,
          ...state.sessions.where((item) => item.id != sessionId),
        ]);

        state = state.copyWith(
          activeSessionId: sessionId,
          sessions: nextSessions,
        );
      }

      final sendResponse = await _repository.sendMessage(
        sessionId: sessionId,
        content: text,
        isDeep: state.isDeepThinking,
        model: state.effectiveChatModel,
        systemPrompt: _assistantSystemRule(),
      );

      if (!sendResponse.isSuccess) {
        _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
        state = state.copyWith(waitingAssistant: false, sending: false);
        return sendResponse.msg.isEmpty ? '发送失败' : sendResponse.msg;
      }

      _setPendingMessageStatus(pendingId, AiChatMessageStatus.sent);
      await _pollMessagesAfterSend(
        sessionId: sessionId,
        previousAiCount: previousAiCount,
      );
      state = state.copyWith(waitingAssistant: false, sending: false);
      return null;
    } catch (_) {
      _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
      state = state.copyWith(waitingAssistant: false, sending: false);
      return '发送失败，请检查网络连接';
    }
  }

  Future<String?> resendMessage(AiChatMessage message) async {
    if (message.type != AiChatMessageType.user) {
      return null;
    }
    if (state.sending || state.activeSessionId == null) {
      return null;
    }

    final text = message.text.trim();
    if (text.isEmpty) {
      return null;
    }

    final previousAiCount = state.messages
        .where((item) => item.type == AiChatMessageType.ai)
        .length;

    _setPendingMessageStatus(message.id, AiChatMessageStatus.sending);
    state = state.copyWith(
      waitingAssistant: true,
      sending: true,
      isNewConversation: false,
    );

    try {
      final sendResponse = await _repository.sendMessage(
        sessionId: state.activeSessionId!,
        content: text,
        isDeep: state.isDeepThinking,
        model: state.effectiveChatModel,
        systemPrompt: _assistantSystemRule(),
      );
      if (!sendResponse.isSuccess) {
        _setPendingMessageStatus(message.id, AiChatMessageStatus.failed);
        state = state.copyWith(waitingAssistant: false, sending: false);
        return sendResponse.msg.isEmpty ? '重新发送失败' : sendResponse.msg;
      }

      _setPendingMessageStatus(message.id, AiChatMessageStatus.sent);
      await _pollMessagesAfterSend(
        sessionId: state.activeSessionId!,
        previousAiCount: previousAiCount,
      );
      state = state.copyWith(waitingAssistant: false, sending: false);
      return null;
    } catch (_) {
      _setPendingMessageStatus(message.id, AiChatMessageStatus.failed);
      state = state.copyWith(waitingAssistant: false, sending: false);
      return '重新发送失败';
    }
  }

  Future<void> _pollMessagesAfterSend({
    required String sessionId,
    required int previousAiCount,
  }) async {
    for (var index = 0; index < 7; index++) {
      await _fetchMessages(sessionId, showLoading: false);
      final aiCount = state.messages
          .where((item) => item.type == AiChatMessageType.ai)
          .length;
      if (aiCount > previousAiCount) {
        return;
      }
      if (index < 6) {
        final delay = index < 2 ? 700 : 1200;
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
  }

  Future<String?> _fetchMessages(
    String sessionId, {
    required bool showLoading,
  }) async {
    if (showLoading) {
      state = state.copyWith(messagesLoading: true);
    }
    try {
      final response = await _repository.getMessages(sessionId);
      if (!response.isSuccess) {
        state = state.copyWith(messagesLoading: false);
        return response.msg.isEmpty ? '加载消息失败' : response.msg;
      }

      final messages = _normalizeMessageList(response.data);
      state = state.copyWith(
        messagesLoading: false,
        messages: messages,
        isNewConversation: messages.isEmpty,
      );
      return null;
    } catch (_) {
      state = state.copyWith(messagesLoading: false);
      return '加载消息失败';
    }
  }

  void _setPendingMessageStatus(String messageId, AiChatMessageStatus status) {
    final next = state.messages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      return message.copyWith(status: status);
    }).toList();
    state = state.copyWith(messages: next);
  }

  List<AiChatSession> _normalizeSessionList(dynamic data) {
    final payload = _extractListPayload(data);
    final result = <AiChatSession>[];
    for (final item in payload) {
      final session = _mapSession(item);
      if (session != null) {
        result.add(session);
      }
    }
    return result;
  }

  List<AiChatMessage> _normalizeMessageList(dynamic data) {
    final payload = _extractListPayload(data);
    final result = <AiChatMessage>[];
    for (final item in payload) {
      final message = _mapMessage(item);
      if (message != null) {
        result.add(message);
      }
    }

    result.sort((a, b) {
      final at = a.sortTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.sortTime?.millisecondsSinceEpoch ?? 0;
      if (at != bt) {
        return at.compareTo(bt);
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  List<AiChatSession> _sortSessions(List<AiChatSession> sessions) {
    final next = [...sessions];
    next.sort((a, b) {
      final at = a.sortTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.sortTime?.millisecondsSinceEpoch ?? 0;
      if (at != bt) {
        return bt.compareTo(at);
      }
      return b.id.compareTo(a.id);
    });
    return next;
  }

  List<dynamic> _extractListPayload(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final records = data['records'];
      if (records is List) {
        return records;
      }
      final list = data['list'];
      if (list is List) {
        return list;
      }
      final rows = data['rows'];
      if (rows is List) {
        return rows;
      }
      final messages = data['messages'];
      if (messages is List) {
        return messages;
      }
    }
    return const [];
  }

  AiChatSession? _mapSession(dynamic raw) {
    final map = _toMap(raw);
    if (map == null) {
      return null;
    }

    final idValue = _readString(
      map['id'] ?? map['sessionId'] ?? map['chatSessionId'],
    );
    if (idValue.isEmpty) {
      return null;
    }

    final title = _readString(
      map['title'] ?? map['name'] ?? map['sessionTitle'],
    );
    final sortTime = _parseDateTime(
      map['updateTime'] ??
          map['updateDate'] ??
          map['createTime'] ??
          map['createDate'] ??
          map['lastMessageTime'] ??
          map['modifyTime'] ??
          map['timestamp'],
    );
    return AiChatSession(
      id: idValue,
      title: title.isEmpty ? '未命名会话' : title,
      sortTime: sortTime,
    );
  }

  AiChatMessage? _mapMessage(dynamic raw) {
    final map = _toMap(raw);
    if (map == null) {
      return null;
    }

    final idValue = _readString(
      map['id'] ??
          map['msgId'] ??
          'msg-${DateTime.now().microsecondsSinceEpoch}-${map.hashCode}',
    );
    final text = _normalizeAssistantDisplayText(_normalizeMessageText(map));
    final reasoning = _normalizeAssistantDisplayText(
      _readString(
        map['reasoning_content'] ??
            map['reasoningContent'] ??
            map['reasoning'] ??
            map['thinking'] ??
            map['thinkContent'],
      ),
    );
    final type = _deduceMessageType(map);

    return AiChatMessage(
      id: idValue,
      type: type,
      text: text,
      status: AiChatMessageStatus.sent,
      reasoning: reasoning,
      reasoningExpanded: false,
      sortTime: _parseDateTime(map['createTime'] ?? map['timestamp']),
    );
  }

  AiChatMessageType _deduceMessageType(Map<String, dynamic> map) {
    final role = _readString(map['role']).toLowerCase();
    if (role == 'user') {
      return AiChatMessageType.user;
    }
    if (role == 'assistant' || role == 'ai') {
      return AiChatMessageType.ai;
    }

    final type = map['type'];
    final messageType = map['messageType'];
    final senderType = map['senderType'];
    final fromUser = map['fromUser'];
    final isSelf = map['isSelf'];

    final looksUser =
        type == 'user' ||
        type == 1 ||
        messageType == 0 ||
        messageType == 'USER' ||
        senderType == 1 ||
        fromUser == true ||
        isSelf == true;
    if (looksUser) {
      return AiChatMessageType.user;
    }
    return AiChatMessageType.ai;
  }

  String _normalizeMessageText(Map<String, dynamic> raw) {
    dynamic value =
        raw['content'] ??
        raw['message'] ??
        raw['text'] ??
        raw['answer'] ??
        raw['body'];

    if (value is Map<String, dynamic>) {
      value = value['content'] ?? value['text'] ?? value['message'];
    }

    final text = _readString(value);
    return _unwrapJsonStringContent(text).trim();
  }

  String _unwrapJsonStringContent(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{')) {
      return trimmed;
    }

    try {
      final map = _toMap(trimmed);
      if (map == null) {
        return trimmed;
      }
      final role = _readString(map['role']).toLowerCase();
      if (role == 'assistant') {
        final content = _readString(map['content']);
        if (content.isNotEmpty) {
          return content;
        }
      }
      final candidate = _readString(
        map['content'] ?? map['text'] ?? map['message'],
      );
      return candidate.isNotEmpty ? candidate : trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  String? _extractSessionId(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is num || data is String) {
      final id = data.toString();
      return id.isEmpty ? null : id;
    }
    if (data is Map<String, dynamic>) {
      final id = _readString(data['id'] ?? data['sessionId']);
      return id.isEmpty ? null : id;
    }
    return null;
  }

  String _titleFromFirstUserMessage(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return '新对话';
    }
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.length <= 50) {
      return firstLine;
    }
    return '${firstLine.substring(0, 50)}...';
  }

  String _assistantSystemRule() {
    return '''
你必须全程扮演“小艺同学”，定位是面向音乐艺考生的备考与学习辅助助手。
只围绕音乐艺考相关内容回答，比如乐理、视唱练耳、听辨、曲目练习、院校方向和备考计划。
如果用户的话题与音乐艺考无关，请先用一句话说明你的定位，再把对话自然引导回音乐学习场景。
不要自称 DeepSeek，不要提及第三方模型公司名称。
回答风格要清晰、友好、专业，优先给出可执行的学习建议和分步骤说明。
如果用户提出的是抽象问题，请尽量结合音乐艺考训练场景举例说明。
''';
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, data) => MapEntry('$key', data));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        return _toMapFromJson(trimmed);
      }
    }
    return null;
  }

  Map<String, dynamic>? _toMapFromJson(String text) {
    try {
      final decoded = jsonDecode(text);
      return _toMap(decoded);
    } catch (_) {
      return null;
    }
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return '$value';
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is num) {
      var millis = raw.toInt();
      if (millis <= 0) {
        return null;
      }
      if (millis < 10000000000) {
        millis *= 1000;
      }
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) {
      return null;
    }
    final asNum = int.tryParse(str);
    if (asNum != null) {
      return _parseDateTime(asNum);
    }
    return DateTime.tryParse(str);
  }

  String _normalizeAssistantDisplayText(String source) {
    if (source.isEmpty) {
      return source;
    }

    var text = source;
    text = text.replaceAll(
      RegExp(r'\bDeepSeek\b', caseSensitive: false),
      '小艺同学',
    );
    text = text.replaceAll(RegExp(r'deepseek', caseSensitive: false), '小艺同学');
    text = text.replaceAll('深度求索公司', '小艺同学');
    text = text.replaceAll('深度求索', '小艺同学');
    return text;
  }
}
