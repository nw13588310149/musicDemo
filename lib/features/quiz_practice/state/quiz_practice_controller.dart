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

  /// 点击练习入口时立即开始加载，与路由 push 并行。
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
    _scheduleIdleWarmUp(summaries);
  }

  void _scheduleIdleWarmUp(List<QuizPracticeSummary> summaries) {
    unawaited(compute(warmupQuizQuestionParser, null));

    final sequence = _sequenceWarmUpCandidate(summaries);
    if (sequence == null) return;
    prefetchSession(sequence);
  }

  QuizPracticeSummary? _sequenceWarmUpCandidate(
    List<QuizPracticeSummary> summaries,
  ) {
    for (final summary in summaries) {
      if (summary.type != QuizPracticeType.sequence) continue;
      if (!summary.statusInitialized) return summary;
      if (summary.allCount <= 0) return null;
      final practiceId = summary.practiceId;
      if (practiceId == null || practiceId <= 0) return null;
      return summary;
    }
    return null;
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
