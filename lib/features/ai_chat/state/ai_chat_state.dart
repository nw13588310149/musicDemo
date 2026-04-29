enum AiChatMessageType { user, ai }

enum AiChatMessageStatus { sending, sent, failed }

class AiChatSession {
  const AiChatSession({required this.id, required this.title, this.sortTime});

  final String id;
  final String title;
  final DateTime? sortTime;
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.type,
    required this.text,
    this.status = AiChatMessageStatus.sent,
    this.reasoning = '',
    this.reasoningExpanded = false,
    this.sortTime,
  });

  final String id;
  final AiChatMessageType type;
  final String text;
  final AiChatMessageStatus status;
  final String reasoning;
  final bool reasoningExpanded;
  final DateTime? sortTime;

  AiChatMessage copyWith({
    String? id,
    AiChatMessageType? type,
    String? text,
    AiChatMessageStatus? status,
    String? reasoning,
    bool? reasoningExpanded,
    DateTime? sortTime,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      status: status ?? this.status,
      reasoning: reasoning ?? this.reasoning,
      reasoningExpanded: reasoningExpanded ?? this.reasoningExpanded,
      sortTime: sortTime ?? this.sortTime,
    );
  }
}

class AiChatSessionGroup {
  const AiChatSessionGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<AiChatSession> items;
}

class AiChatState {
  const AiChatState({
    this.sidebarCollapsed = false,
    this.isDeepThinking = false,
    this.isWebSearching = false,
    this.sessionsLoading = false,
    this.messagesLoading = false,
    this.sending = false,
    this.waitingAssistant = false,
    this.isNewConversation = true,
    this.activeSessionId,
    this.sessions = const [],
    this.messages = const [],
  });

  final bool sidebarCollapsed;
  final bool isDeepThinking;
  final bool isWebSearching;
  final bool sessionsLoading;
  final bool messagesLoading;
  final bool sending;
  final bool waitingAssistant;
  final bool isNewConversation;
  final String? activeSessionId;
  final List<AiChatSession> sessions;
  final List<AiChatMessage> messages;

  String get effectiveChatModel {
    return isDeepThinking ? 'deepseek-reasoner' : 'deepseek-chat';
  }

  AiChatState copyWith({
    bool? sidebarCollapsed,
    bool? isDeepThinking,
    bool? isWebSearching,
    bool? sessionsLoading,
    bool? messagesLoading,
    bool? sending,
    bool? waitingAssistant,
    bool? isNewConversation,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    List<AiChatSession>? sessions,
    List<AiChatMessage>? messages,
  }) {
    return AiChatState(
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      isDeepThinking: isDeepThinking ?? this.isDeepThinking,
      isWebSearching: isWebSearching ?? this.isWebSearching,
      sessionsLoading: sessionsLoading ?? this.sessionsLoading,
      messagesLoading: messagesLoading ?? this.messagesLoading,
      sending: sending ?? this.sending,
      waitingAssistant: waitingAssistant ?? this.waitingAssistant,
      isNewConversation: isNewConversation ?? this.isNewConversation,
      activeSessionId: clearActiveSessionId
          ? null
          : (activeSessionId ?? this.activeSessionId),
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
    );
  }
}

List<AiChatSessionGroup> groupSessionsByTime(List<AiChatSession> sessions) {
  if (sessions.isEmpty) {
    return const [];
  }

  final sorted = [...sessions]
    ..sort((a, b) {
      final at = a.sortTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.sortTime?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final todayStart = startOfToday.millisecondsSinceEpoch;
  final withinSevenDays = todayStart - 7 * 86400000;
  final withinThirtyDays = todayStart - 30 * 86400000;

  final today = <AiChatSession>[];
  final week = <AiChatSession>[];
  final month = <AiChatSession>[];
  final older = <AiChatSession>[];

  for (final session in sorted) {
    final time = session.sortTime?.millisecondsSinceEpoch ?? 0;
    if (time == 0) {
      older.add(session);
      continue;
    }
    if (time >= todayStart) {
      today.add(session);
    } else if (time >= withinSevenDays) {
      week.add(session);
    } else if (time >= withinThirtyDays) {
      month.add(session);
    } else {
      older.add(session);
    }
  }

  final groups = <AiChatSessionGroup>[];
  if (today.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'today', label: '今天', items: today));
  }
  if (week.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'week', label: '7天内', items: week));
  }
  if (month.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'month', label: '30天内', items: month));
  }
  if (older.isNotEmpty) {
    groups.add(AiChatSessionGroup(key: 'older', label: '更早', items: older));
  }
  return groups;
}
