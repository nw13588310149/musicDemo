import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import '../data/quiz_question_parser.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_state.dart';

final quizSessionLoaderProvider = Provider<QuizSessionLoader>((ref) {
  final repo = ref.watch(quizPracticeRepositoryProvider);
  return QuizSessionLoader(repository: repo);
});

/// 加载做题页完整题目列表的结果。
class QuizSessionLoadResult {
  const QuizSessionLoadResult({
    required this.questions,
    required this.errorMessage,
  });

  /// 完整题目列表；为 null 表示加载失败或空列表。
  final List<QuizQuestion>? questions;
  final String errorMessage;

  bool get isSuccess => errorMessage.isEmpty;
}

class _CachedResult {
  _CachedResult(this.result) : createdAt = DateTime.now();

  final QuizSessionLoadResult result;
  final DateTime createdAt;

  static const Duration _ttl = Duration(minutes: 2);

  bool get isExpired => DateTime.now().difference(createdAt) > _ttl;
}

/// 做题页题目加载器。
///
/// - 缓存 key：`schoolId:practiceType:practiceId`（不含 startIndex，
///   startIndex 由 controller 从路由参数独立处理）。
/// - 同一 key 的 in-flight 请求自动去重，不会重复发网络请求。
/// - 所有题目在一次 [compute] 调用中解析，摊销 web worker 冷启动开销。
class QuizSessionLoader {
  QuizSessionLoader({required QuizPracticeRepository repository})
    : _repository = repository;

  final QuizPracticeRepository _repository;

  final Map<String, Future<QuizSessionLoadResult>> _inflight = {};
  final Map<String, _CachedResult> _cache = {};

  static String _cacheKey(QuizSessionPageArgs args) =>
      '${args.schoolId}:${args.practiceType.apiKey}:${args.practiceId ?? 0}';

  /// 预热：后台静默加载并缓存，供点击时秒进使用。
  void warmUp(QuizSessionPageArgs args) {
    unawaited(load(args));
  }

  /// 加载完整题目列表；缓存命中立即返回，否则发起网络请求。
  Future<QuizSessionLoadResult> load(QuizSessionPageArgs args) {
    final key = _cacheKey(args);

    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached.result);
    }
    if (cached != null) _cache.remove(key);

    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final future = _fetch(args, key);
    _inflight[key] = future;
    return future.whenComplete(() => _inflight.remove(key));
  }

  /// 清除缓存（例如练习完成后调用，确保下次重新拉取最新数据）。
  void invalidate(QuizSessionPageArgs args) {
    _cache.remove(_cacheKey(args));
  }

  Future<QuizSessionLoadResult> _fetch(
    QuizSessionPageArgs args,
    String key,
  ) async {
    var practiceId = args.practiceId;

    // createPractice 已在 camp 页后台完成；此处仅 deep-link / 异常兜底。
    if ((practiceId == null || practiceId <= 0) &&
        args.practiceType != QuizPracticeType.error) {
      final created = await _repository.createPractice(
        schoolId: args.schoolId,
        practiceType: args.practiceType.apiKey,
      );
      if (created.isSuccess && created.data is Map) {
        practiceId = _toInt((created.data as Map)['practiceId']);
      }
      if (practiceId == null || practiceId <= 0) {
        return QuizSessionLoadResult(
          questions: null,
          errorMessage: created.displayMsg,
        );
      }
    }

    if (practiceId == null || practiceId <= 0) {
      return const QuizSessionLoadResult(
        questions: null,
        errorMessage: '',
      );
    }

    final response = await _repository.getItemList(
      schoolId: args.schoolId,
      practiceId: practiceId,
      practiceType: args.practiceType.apiKey,
    );
    if (!response.isSuccess) {
      return QuizSessionLoadResult(
        questions: null,
        errorMessage: response.displayMsg,
      );
    }

    final rawList = response.data;
    if (rawList is! List || rawList.isEmpty) {
      return const QuizSessionLoadResult(questions: null, errorMessage: '');
    }

    // 在单个 isolate 中一次性解析所有题目，摊销 web worker 冷启动开销。
    final payloads = await compute(parseQuizQuestionsPayload, rawList);
    final questions = payloads
        .map(QuizQuestion.fromPayload)
        .toList(growable: false);

    if (questions.isEmpty) {
      return const QuizSessionLoadResult(questions: null, errorMessage: '');
    }

    final result = QuizSessionLoadResult(
      questions: questions,
      errorMessage: '',
    );
    _cache[key] = _CachedResult(result);
    return result;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
