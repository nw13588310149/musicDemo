/// 群聊 syncMsg / WS 推送 payload 解析辅助。
abstract final class ChatSyncPayload {
  /// syncMsg / msgList 等接口返回的消息数组。
  ///
  /// 后端常见结构：`{ msgList: [...], userList: [...] }` 或裸数组。
  static List<dynamic> extractMessageList(Object? raw) {
    if (raw is List) return raw;
    if (raw is! Map) return const [];

    for (final key in ['msgList', 'records', 'list', 'messages']) {
      final value = raw[key];
      if (value is List) return value;
    }
    final data = raw['data'];
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['msgList', 'records', 'list', 'messages']) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  /// WS 帧可能把消息体包在 data/msg 等字段里。
  static Map<String, dynamic> normalizePush(Map<String, dynamic> payload) {
    for (final key in ['data', 'msg', 'body', 'message', 'payload']) {
      final nested = payload[key];
      if (nested is Map) {
        final map = nested.map((k, v) => MapEntry(k.toString(), v));
        if (map['classId'] != null || map['cId'] != null) {
          if (map['type'] == null && payload['type'] != null) {
            return {...map, 'type': payload['type']};
          }
          return map;
        }
      }
    }
    return payload;
  }

  static bool hasChatIdentity(Map<String, dynamic> json) {
    return json['classId'] != null ||
        json['cId'] != null ||
        json['fromUserId'] != null ||
        json['msgId'] != null ||
        json['id'] != null ||
        json['messageId'] != null;
  }
}
