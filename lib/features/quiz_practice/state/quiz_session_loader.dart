import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/quiz_practice_repository.dart';
import '../data/quiz_question_parser.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_state.dart';

final quizSessionLoaderProvider = Provider<QuizSessionLoader>((ref) {
  final repo = ref.watch(quizPracticeRepositoryProvider);
  return QuizSessionLoader(repository: repo);
});

class QuizSessionBootstrapResult {
  const QuizSessionBootstrapResult({
    required this.questions,
    required this.startIndex,
    required this.errorMessage,
  });

  final List<QuizQuestion> questions;
  final int startIndex;
  final String errorMessage;

  bool get isSuccess => errorMessage.isEmpty;
}

class QuizSessionBootstrapPartial {
  const QuizSessionBootstrapPartial({
    required this.questions,
    required this.currentIndex,
  });

  final List<QuizQuestion> questions;
  final int currentIndex;
}

typedef QuizSessionBootstrapPartialCallback =
    void Function(QuizSessionBootstrapPartial partial);

class _BootstrapJob {
  _BootstrapJob(this.future);

  final Future<QuizSessionBootstrapResult> future;
  QuizSessionBootstrapPartial? latestPartial;
  final List<QuizSessionBootstrapPartialCallback> listeners =
      <QuizSessionBootstrapPartialCallback>[];
}

/// 做题页 bootstrap 共享加载器：camp 页点击时即可开始请求，session 页复用同一 Future。
class QuizSessionLoader {
  QuizSessionLoader({required QuizPracticeRepository repository})
    : _repository = repository;

  final QuizPracticeRepository _repository;
  final Map<String, _BootstrapJob> _jobs = <String, _BootstrapJob>{};

  static String cacheKey(QuizSessionPageArgs args) {
    return '${args.schoolId}:${args.practiceType.apiKey}:'
        '${args.practiceId ?? 0}:${args.startIndex}:${args.needsInitialize}';
  }

  /// 立即开始 bootstrap（可重复调用，同一 [args] 只会发起一次网络流程）。
  Future<QuizSessionBootstrapResult> load(
    QuizSessionPageArgs args, {
    QuizSessionBootstrapPartialCallback? onPartial,
  }) {
    final key = cacheKey(args);
    final job = _jobs.putIfAbsent(
      key,
      () => _BootstrapJob(_bootstrap(args, key)),
    );
    if (onPartial != null) {
      _listen(job, onPartial);
    }
    return job.future.whenComplete(() => _jobs.remove(key));
  }

  /// camp 页空闲预热：不阻塞 UI，也不重复占用进行中的同一请求。
  void warmUp(QuizSessionPageArgs args) {
    unawaited(load(args));
  }

  void _listen(_BootstrapJob job, QuizSessionBootstrapPartialCallback listener) {
    final cached = job.latestPartial;
    if (cached != null) {
      listener(cached);
    }
    if (!job.listeners.contains(listener)) {
      job.listeners.add(listener);
    }
  }

  void _emitPartial(String key, QuizSessionBootstrapPartial partial) {
    final job = _jobs[key];
    if (job == null) return;
    job.latestPartial = partial;
    for (final listener in job.listeners) {
      listener(partial);
    }
  }

  Future<QuizSessionBootstrapResult> _bootstrap(
    QuizSessionPageArgs args,
    String key,
  ) async {
    var practiceId = args.practiceId;
    ApiResponse? createdResponse;

    final needsCreate =
        args.needsInitialize || practiceId == null || practiceId <= 0;
    if (needsCreate && args.practiceType != QuizPracticeType.error) {
      createdResponse = await _repository.createPractice(
        schoolId: args.schoolId,
        practiceType: args.practiceType.apiKey,
      );
      if (createdResponse.isSuccess && createdResponse.data is Map) {
        final data = createdResponse.data as Map;
        practiceId = _toInt(data['practiceId']);
      }
    }

    if (practiceId == null || practiceId <= 0) {
      return QuizSessionBootstrapResult(
        questions: const <QuizQuestion>[],
        startIndex: 0,
        errorMessage: createdResponse?.displayMsg ?? '',
      );
    }

    final response = await _repository.getItemList(
      schoolId: args.schoolId,
      practiceId: practiceId,
      practiceType: args.practiceType.apiKey,
    );
    if (!response.isSuccess) {
      return QuizSessionBootstrapResult(
        questions: const <QuizQuestion>[],
        startIndex: 0,
        errorMessage: response.displayMsg,
      );
    }

    final raw = response.data;
    if (raw is! List || raw.isEmpty) {
      return QuizSessionBootstrapResult(
        questions: const <QuizQuestion>[],
        startIndex: 0,
        errorMessage: '',
      );
    }

    var startIndex = args.startIndex;
    if (startIndex >= raw.length) {
      startIndex = raw.length - 1;
    }
    if (startIndex < 0) startIndex = 0;

    // 首题优先：主线程解析单题，尽快结束 loading；全量解析仍在 isolate 中完成。
    final firstPayloads = parseQuizQuestionsPayload(<dynamic>[raw[startIndex]]);
    if (firstPayloads.isNotEmpty) {
      _emitPartial(
        key,
        QuizSessionBootstrapPartial(
          questions: <QuizQuestion>[
            QuizQuestion.fromPayload(firstPayloads.first),
          ],
          currentIndex: 0,
        ),
      );
    }

    final payloads = await compute(parseQuizQuestionsPayload, raw);
    final questions = payloads
        .map(QuizQuestion.fromPayload)
        .toList(growable: false);

    final total = questions.isEmpty ? args.allCount : questions.length;
    var resolvedStartIndex = startIndex;
    if (total > 0 && resolvedStartIndex >= total) {
      resolvedStartIndex = total - 1;
    }
    if (resolvedStartIndex < 0) resolvedStartIndex = 0;

    return QuizSessionBootstrapResult(
      questions: questions,
      startIndex: resolvedStartIndex,
      errorMessage: '',
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
