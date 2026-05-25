import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/quiz_practice_repository.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_question_store.dart';
import 'quiz_session_state.dart';

final quizSessionLoaderProvider = Provider<QuizSessionLoader>((ref) {
  final repo = ref.watch(quizPracticeRepositoryProvider);
  return QuizSessionLoader(repository: repo);
});

class QuizSessionBootstrapResult {
  const QuizSessionBootstrapResult({
    required this.store,
    required this.startIndex,
    required this.errorMessage,
  });

  final QuizSessionQuestionStore? store;
  final int startIndex;
  final String errorMessage;

  bool get isSuccess => errorMessage.isEmpty;
}

class QuizSessionBootstrapPartial {
  const QuizSessionBootstrapPartial({
    required this.store,
    required this.startIndex,
  });

  final QuizSessionQuestionStore store;
  final int startIndex;
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

class _CachedBootstrapResult {
  _CachedBootstrapResult(this.result) : createdAt = DateTime.now();

  final QuizSessionBootstrapResult result;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}

/// 做题页 bootstrap 共享加载器：只拉取原始列表 + 轻量 stub，HTML 按需解析。
class QuizSessionLoader {
  QuizSessionLoader({required QuizPracticeRepository repository})
    : _repository = repository;

  final QuizPracticeRepository _repository;
  final Map<String, _BootstrapJob> _jobs = <String, _BootstrapJob>{};
  final Map<String, _CachedBootstrapResult> _cache =
      <String, _CachedBootstrapResult>{};

  static const Duration _cacheTtl = Duration(minutes: 2);

  static String cacheKey(QuizSessionPageArgs args) {
    return '${args.schoolId}:${args.practiceType.apiKey}:'
        '${args.practiceId ?? 0}:${args.startIndex}:${args.needsInitialize}';
  }

  Future<QuizSessionBootstrapResult> load(
    QuizSessionPageArgs args, {
    QuizSessionBootstrapPartialCallback? onPartial,
  }) {
    final key = cacheKey(args);
    final cached = _validCachedResult(key);
    if (cached != null) {
      final store = cached.store;
      if (onPartial != null && store != null) {
        onPartial(
          QuizSessionBootstrapPartial(
            store: store,
            startIndex: cached.startIndex,
          ),
        );
      }
      return Future<QuizSessionBootstrapResult>.value(cached);
    }

    final job = _jobs.putIfAbsent(
      key,
      () => _BootstrapJob(
        _bootstrap(args, key).then((result) {
          if (result.isSuccess && result.store != null) {
            _cache[key] = _CachedBootstrapResult(result);
          }
          return result;
        }),
      ),
    );
    if (onPartial != null) {
      _listen(job, onPartial);
    }
    return job.future.whenComplete(() => _jobs.remove(key));
  }

  void warmUp(QuizSessionPageArgs args) {
    unawaited(load(args));
  }

  QuizSessionBootstrapResult? _validCachedResult(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    if (cached.isExpired(_cacheTtl)) {
      _cache.remove(key);
      return null;
    }
    return cached.result;
  }

  void _listen(
    _BootstrapJob job,
    QuizSessionBootstrapPartialCallback listener,
  ) {
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

    // create 已在 camp 页完成；这里仅 deep link / 异常兜底。
    final needsCreate = practiceId == null || practiceId <= 0;
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
        store: null,
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
        store: null,
        startIndex: 0,
        errorMessage: response.displayMsg,
      );
    }

    final raw = response.data;
    if (raw is! List || raw.isEmpty) {
      return const QuizSessionBootstrapResult(
        store: null,
        startIndex: 0,
        errorMessage: '',
      );
    }

    final stubs = parseQuizQuestionStubs(raw);
    if (stubs.isEmpty) {
      return const QuizSessionBootstrapResult(
        store: null,
        startIndex: 0,
        errorMessage: '',
      );
    }

    final store = QuizSessionQuestionStore(rawItems: raw, stubs: stubs);

    var startIndex = args.startIndex;
    if (startIndex >= store.totalCount) {
      startIndex = store.totalCount - 1;
    }
    if (startIndex < 0) startIndex = 0;

    try {
      await store.resolveAt(startIndex);
    } catch (_) {
      // 首题解析失败时仍下发 stub 列表，由做题页重试。
    }

    _emitPartial(
      key,
      QuizSessionBootstrapPartial(store: store, startIndex: startIndex),
    );

    return QuizSessionBootstrapResult(
      store: store,
      startIndex: startIndex,
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
