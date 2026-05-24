import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import 'quiz_practice_state.dart';

final quizPracticeControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizPracticeController, QuizPracticeState, int>((ref, schoolId) {
      final repo = ref.watch(quizPracticeRepositoryProvider);
      return QuizPracticeController(repository: repo, schoolId: schoolId);
    });

class QuizPracticeController extends StateNotifier<QuizPracticeState> {
  QuizPracticeController({
    required QuizPracticeRepository repository,
    required int schoolId,
  }) : _repository = repository,
       _schoolId = schoolId,
       super(QuizPracticeState.initial) {
    unawaited(refresh());
  }

  final QuizPracticeRepository _repository;
  final int _schoolId;
  final Set<QuizPracticeType> _initializingTypes = <QuizPracticeType>{};

  int get schoolId => _schoolId;

  /// 进入做题页前确保该练习已 create 初始化，避免 session 页重复请求。
  Future<QuizPracticeSummary?> ensurePracticeReady(QuizPracticeType type) async {
    if (type == QuizPracticeType.error) {
      return state.summaryOf(type);
    }

    await _waitForSummaryLoaded();

    var summary = state.summaryOf(type);
    if (summary == null) return null;

    final needsInit =
        !summary.statusInitialized ||
        summary.practiceId == null ||
        summary.practiceId! <= 0;
    if (needsInit) {
      await _initializePractice(type);
      summary = state.summaryOf(type);
    }

    return summary;
  }

  Future<void> _waitForSummaryLoaded() async {
    if (!state.loading || state.summaries.isNotEmpty) return;
    const maxAttempts = 120;
    for (var i = 0; i < maxAttempts; i++) {
      if (!mounted) return;
      if (!state.loading || state.summaries.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
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
        errorMessage: response.msg.isEmpty ? '加载刷题数据失败' : response.msg,
      );
      return;
    }

    final summaries = _parseSummaries(response.data);
    state = state.copyWith(loading: false, summaries: summaries);

    // 1.0 行为：status==null 的练习立刻调用 create 初始化（只针对 sequence/random/exam）。
    final missing = summaries
        .where((s) => !s.statusInitialized && s.type != QuizPracticeType.error)
        .toList(growable: false);
    if (missing.isEmpty) return;
    await Future.wait(
      missing.map((s) => _initializePractice(s.type)),
      eagerError: false,
    );
  }

  Future<void> _initializePractice(QuizPracticeType type) async {
    if (_initializingTypes.contains(type)) {
      while (_initializingTypes.contains(type) && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _initializingTypes.add(type);
    try {
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
    } finally {
      _initializingTypes.remove(type);
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
