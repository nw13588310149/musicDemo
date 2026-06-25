/// 班主任端「家校沟通」API 数据模型与 JSON 解析。
library;

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';

class HomeSchoolChatStat {
  const HomeSchoolChatStat({
    required this.totalCount,
    required this.unreadCount,
    required this.waitingReplyCount,
  });

  final int totalCount;
  final int unreadCount;
  final int waitingReplyCount;

  static const zero = HomeSchoolChatStat(
    totalCount: 0,
    unreadCount: 0,
    waitingReplyCount: 0,
  );
}

class HomeSchoolConversation {
  const HomeSchoolConversation({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.studentName,
    required this.studentNo,
    required this.studentHeadUrl,
    required this.parentName,
    required this.parentMobile,
    required this.parentHeadUrl,
    required this.parentRelation,
    required this.tags,
    required this.lastSpeaker,
    required this.lastMessage,
    required this.timeText,
    required this.unreadCount,
    required this.replyPending,
  });

  final String id;
  final String studentId;
  final String parentId;
  final String studentName;
  final String studentNo;
  final String? studentHeadUrl;
  final String parentName;
  final String parentMobile;
  final String? parentHeadUrl;
  final String parentRelation;
  final List<String> tags;
  final String lastSpeaker;
  final String lastMessage;
  final String timeText;
  final int unreadCount;
  final bool replyPending;

  /// 展示用学生名：优先 [studentName]，否则 [studentNo]。
  String get displayStudentName {
    if (studentName.isNotEmpty) return studentName;
    if (studentNo.isNotEmpty && studentNo != '—') return studentNo;
    return '未命名学生';
  }

  /// 展示用家长名：优先 [parentName]，否则 [parentMobile]。
  String get displayParentName {
    if (parentName.isNotEmpty) return parentName;
    if (parentMobile.isNotEmpty) return parentMobile;
    return '家长';
  }

  bool get hasStudentName => studentName.isNotEmpty;
  bool get hasParentName => parentName.isNotEmpty;
}

class HomeSchoolChatMessage {
  const HomeSchoolChatMessage({
    required this.id,
    required this.content,
    required this.timeText,
    required this.fromTeacher,
  });

  final String id;
  final String content;
  final String timeText;
  final bool fromTeacher;
}

HomeSchoolChatStat parseHomeSchoolChatStat(dynamic raw) {
  if (raw is! Map) return HomeSchoolChatStat.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }
  return HomeSchoolChatStat(
    totalCount: _asInt(m['totalCount']) ?? 0,
    unreadCount: _asInt(m['unreadCount']) ?? 0,
    waitingReplyCount: _asInt(m['waitingReplyCount']) ?? 0,
  );
}

List<HomeSchoolConversation> parseHomeSchoolConversationList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <HomeSchoolConversation>[];
  for (final m in rows) {
    final id = readSnowflakeId(m['id']) ?? m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final studentId =
        readSnowflakeId(m['studentId']) ?? m['studentId']?.toString() ?? '';
    final parentId =
        readSnowflakeId(m['parentId']) ?? m['parentId']?.toString() ?? '';
    final tagsRaw = _pickString(m, ['studentTags'], '');
    final tags = tagsRaw.isEmpty
        ? const <String>[]
        : tagsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    final senderType = _pickString(m, ['lastSenderType'], '');
    final studentNoRaw = _pickString(m, ['studentNo'], '');
    final studentName = _pickString(m, ['studentName'], '');
    final parentMobile = _pickString(m, ['parentMobile'], '');
    final parentName = _pickString(m, ['parentName'], '');
    parsed.add(
      HomeSchoolConversation(
        id: id,
        studentId: studentId,
        parentId: parentId,
        studentName: studentName,
        studentNo: studentNoRaw.isNotEmpty ? studentNoRaw : '—',
        studentHeadUrl: _resolveOptionalUrl(m['studentHeadUrl']),
        parentName: parentName,
        parentMobile: parentMobile,
        parentHeadUrl: _resolveOptionalUrl(m['parentHeadUrl']),
        parentRelation: _pickString(m, ['parentRelation'], '家长'),
        tags: tags,
        lastSpeaker: senderType == 'teacher' ? '老师' : '家长',
        lastMessage: _pickString(m, ['lastMessage'], ''),
        timeText: _formatDisplayTime(m['lastMessageTime']),
        unreadCount: _asInt(m['unreadCount']) ?? 0,
        replyPending: m['waitingReply'] == true ||
            m['waitingReply']?.toString() == 'true' ||
            m['waitingReply'] == 1,
      ),
    );
  }
  return parsed;
}

List<HomeSchoolChatMessage> parseHomeSchoolChatMessageList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <HomeSchoolChatMessage>[];
  for (final m in rows) {
    final id = readSnowflakeId(m['id']) ?? m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final senderType = _pickString(m, ['senderType'], '');
    parsed.add(
      HomeSchoolChatMessage(
        id: id,
        content: _pickString(m, ['content'], ''),
        timeText: _formatDisplayTime(m['createTime']),
        fromTeacher: senderType == 'teacher',
      ),
    );
  }
  return parsed;
}

List<Map<String, dynamic>> _extractRecordMaps(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (raw is Map) {
    final m = raw.cast<String, dynamic>();
    if (m['records'] is List) {
      return [
        for (final item in m['records'] as List)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    if (m['data'] is Map) {
      return _extractRecordMaps(m['data']);
    }
    if (m['data'] is List) {
      return _extractRecordMaps(m['data']);
    }
  }
  return const [];
}

String? _resolveOptionalUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return MediaUrl.resolve(s);
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return fallback;
}

int? _asInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

String _formatDisplayTime(dynamic raw) {
  if (raw == null) return '—';
  final s = raw.toString().trim();
  if (s.isEmpty) return '—';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(local.hour)}:${two(local.minute)}';
  if (day == today) return '今天 $hm';
  if (day == today.subtract(const Duration(days: 1))) return '昨天 $hm';
  return '${local.month}-${two(local.day)} $hm';
}
