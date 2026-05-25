import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/quiz_question_parser.dart';
import 'quiz_session_state.dart';

/// 从接口条目提取的轻量元数据，不做 HTML strip。
@immutable
class QuizQuestionStub {
  const QuizQuestionStub({
    required this.itemId,
    required this.correctAnswer,
    required this.userAnswer,
    required this.status,
  });

  final int itemId;
  final int correctAnswer;
  final int? userAnswer;
  final int status;

  bool get answered => status != 0;

  QuizQuestionStub copyWith({int? userAnswer, int? status}) {
    return QuizQuestionStub(
      itemId: itemId,
      correctAnswer: correctAnswer,
      userAnswer: userAnswer ?? this.userAnswer,
      status: status ?? this.status,
    );
  }
}

/// 懒加载题目仓库：保留原始 JSON，仅按需解析 HTML 并 LRU 缓存。
class QuizSessionQuestionStore {
  QuizSessionQuestionStore({
    required List<dynamic> rawItems,
    required List<QuizQuestionStub> stubs,
    int maxCacheSize = 24,
  }) : _rawItems = List<dynamic>.unmodifiable(rawItems),
       stubs = List<QuizQuestionStub>.from(stubs, growable: true),
       _maxCacheSize = maxCacheSize;

  final List<dynamic> _rawItems;
  final List<QuizQuestionStub> stubs;
  final int _maxCacheSize;

  final Map<int, QuizQuestion> _cache = <int, QuizQuestion>{};
  final LinkedHashMap<int, void> _lru = LinkedHashMap<int, void>();
  final Map<int, Future<QuizQuestion>> _inflight = <int, Future<QuizQuestion>>{};

  int get totalCount => stubs.length;

  int get answeredCount => stubs.where((stub) => stub.status != 0).length;

  int get errorCount => stubs.where((stub) => stub.status == 2).length;

  int get notDoneCount => stubs.where((stub) => stub.status == 0).length;

  int get accuracyPercent {
    final done = answeredCount;
    if (done <= 0) return 0;
    return (((done - errorCount) / done) * 100).round();
  }

  QuizQuestionStub stubAt(int index) => stubs[index];

  QuizQuestion? cachedAt(int index) => _cache[index];

  Future<QuizQuestion> resolveAt(int index) {
    if (index < 0 || index >= totalCount) {
      return Future<QuizQuestion>.error(RangeError.index(index, stubs));
    }

    final cached = _cache[index];
    if (cached != null) {
      _touchLru(index);
      return Future<QuizQuestion>.value(cached);
    }

    final pending = _inflight[index];
    if (pending != null) return pending;

    final future = _parseAt(index);
    _inflight[index] = future;
    return future.whenComplete(() => _inflight.remove(index));
  }

  void prefetchAround(int index) {
    prefetch(index + 1);
    prefetch(index - 1);
  }

  void prefetch(int index) {
    if (index < 0 || index >= totalCount) return;
    if (_cache.containsKey(index) || _inflight.containsKey(index)) return;
    unawaited(resolveAt(index));
  }

  void updateAnswer({
    required int index,
    required int userAnswer,
    required int status,
  }) {
    if (index < 0 || index >= totalCount) return;
    stubs[index] = stubs[index].copyWith(
      userAnswer: userAnswer,
      status: status,
    );
    final cached = _cache[index];
    if (cached != null) {
      _cache[index] = cached.copyWith(userAnswer: userAnswer, status: status);
    }
  }

  Future<QuizQuestion> _parseAt(int index) async {
    final payload = await compute(parseQuizQuestionItem, _rawItems[index]);
    if (payload.isEmpty || payload['itemId'] == null) {
      throw StateError('Failed to parse quiz question at index $index');
    }
    var question = QuizQuestion.fromPayload(payload);
    final stub = stubs[index];
    if (stub.userAnswer != question.userAnswer || stub.status != question.status) {
      question = question.copyWith(
        userAnswer: stub.userAnswer,
        status: stub.status,
      );
    }
    _remember(index, question);
    return question;
  }

  void _remember(int index, QuizQuestion question) {
    _cache[index] = question;
    _touchLru(index);
    while (_lru.length > _maxCacheSize) {
      final evictIndex = _lru.keys.first;
      _lru.remove(evictIndex);
      _cache.remove(evictIndex);
    }
  }

  void _touchLru(int index) {
    _lru.remove(index);
    _lru[index] = null;
  }
}

List<QuizQuestionStub> parseQuizQuestionStubs(dynamic data) {
  if (data is! List) return const <QuizQuestionStub>[];

  final stubs = <QuizQuestionStub>[];
  for (final item in data) {
    if (item is! Map) continue;
    final question = item['question'];
    if (question is! Map) continue;

    final id = _toInt(item['id']);
    if (id == null) continue;

    stubs.add(
      QuizQuestionStub(
        itemId: id,
        correctAnswer: _toInt(question['answer']) ?? 0,
        userAnswer: _toInt(item['answer']),
        status: _toInt(item['status']) ?? 0,
      ),
    );
  }
  return stubs;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
