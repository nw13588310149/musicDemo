import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import '../data/quiz_question_parser.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_loader.dart';
import 'quiz_session_state.dart';

final quizPracticeControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizPracticeController, QuizPracticeState, int>((ref, schoolId) {
      final repo = ref.watch(quizPracticeRepositoryProvider);
      final loader = ref.watch(quizSessionLoaderProvider);
      return QuizPracticeController(
        repository: repo,
        loader: loader,
        schoolId: schoolId,
      );
    });

class QuizPracticeController extends StateNotifier<QuizPracticeState> {
  QuizPracticeController({
    required QuizPracticeRepository repository,
    required QuizSessionLoader loader,
    required int schoolId,
  }) : _repository = repository,
       _loader = loader,
       _schoolId = schoolId,
       super(QuizPracticeState.initial) {
    unawaited(refresh());
  }

  final QuizPracticeRepository _repository;
  final QuizSessionLoader _loader;
  final int _schoolId;

  int get schoolId => _schoolId;

  /// camp 页汇总加载完成后，后台预热已初始化练习的题目列表。
  void prefetchSession(QuizPracticeSummary summary) {
    _loader.warmUp(
      QuizSessionPageArgs.fromSummary(summary, schoolId: _schoolId),
    );
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading || state.summaries.isEmpty) {
      state = state.copyWith(loading: true, clearErrorMessage: true);
    }
    final response = await _repository.getSummary(schoolId: _schoolId);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        summaries: _fallbackSummaries(),
        errorMessage: response.displayMsg,
      );
      return;
    }

    final summaries = _parseSummaries(response.data);
    state = state.copyWith(loading: false, summaries: summaries);

    unawaited(compute(warmupQuizQuestionParser, null));
    // 1.0：status==null 时在 camp 页并行 create，点击时 practiceId 已就绪。
    unawaited(_initializeMissingPractices(summaries));
  }

  Future<void> _initializeMissingPractices(
    List<QuizPracticeSummary> summaries,
  ) async {
    final missing = summaries
        .where((s) => !s.statusInitialized && s.type != QuizPracticeType.error)
        .toList(growable: false);

    if (missing.isNotEmpty) {
      await Future.wait(
        missing.map((s) => _initializePractice(s.type)),
        eagerError: false,
      );
    }

    if (!mounted) return;
    _prefetchReadySessions(state.summaries);
  }

  Future<void> _initializePractice(QuizPracticeType type) async {
    final response = await _repository.createPractice(
      schoolId: _schoolId,
      practiceType: type.apiKey,
    );
    if (!mounted || !response.isSuccess) return;

    final updated = _parseSinglePractice(type, response.data);
    if (updated == null) return;

    final next = state.summaries
        .map((s) => s.type == type ? updated : s)
        .toList(growable: false);
    state = state.copyWith(summaries: next);
  }

  void _prefetchReadySessions(List<QuizPracticeSummary> summaries) {
    for (final summary in summaries) {
      if (summary.type == QuizPracticeType.error) continue;
      if (!summary.statusInitialized) continue;
      if (summary.allCount <= 0) continue;
      final practiceId = summary.practiceId;
      if (practiceId == null || practiceId <= 0) continue;
      prefetchSession(summary);
    }
  }

  List<QuizPracticeSummary> _parseSummaries(dynamic data) {
    if (data is! Map) return _fallbackSummaries();

    QuizPracticeSummary parse(QuizPracticeType t) {
      final raw = data[t.apiKey];
      if (raw is! Map) return QuizPracticeSummary.empty(t);
      return QuizPracticeSummary(
        type: t,
        practiceId: _toInt(raw['practiceId']),
        allCount: _toInt(raw['allCount']) ?? 0,
        doneCount: _toInt(raw['doneCount']) ?? 0,
        errorCount: _toInt(raw['errorCount']) ?? 0,
        notDoneCount: _toInt(raw['notDoneCount']) ?? 0,
        statusInitialized: raw['status'] != null,
      );
    }

    return <QuizPracticeSummary>[
      parse(QuizPracticeType.sequence),
      parse(QuizPracticeType.random),
      parse(QuizPracticeType.exam),
      parse(QuizPracticeType.error),
    ];
  }

  QuizPracticeSummary? _parseSinglePractice(
    QuizPracticeType type,
    dynamic data,
  ) {
    if (data is! Map) return null;
    return QuizPracticeSummary(
      type: type,
      practiceId: _toInt(data['practiceId']),
      allCount: _toInt(data['allCount']) ?? 0,
      doneCount: _toInt(data['doneCount']) ?? 0,
      errorCount: _toInt(data['errorCount']) ?? 0,
      notDoneCount: _toInt(data['notDoneCount']) ?? 0,
      statusInitialized: true,
    );
  }

  List<QuizPracticeSummary> _fallbackSummaries() => <QuizPracticeSummary>[
    QuizPracticeSummary.empty(QuizPracticeType.sequence),
    QuizPracticeSummary.empty(QuizPracticeType.random),
    QuizPracticeSummary.empty(QuizPracticeType.exam),
    QuizPracticeSummary.empty(QuizPracticeType.error),
  ];

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
