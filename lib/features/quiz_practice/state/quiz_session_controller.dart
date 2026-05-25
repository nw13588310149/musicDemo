import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_loader.dart';
import 'quiz_session_state.dart';

final quizSessionControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizSessionController, QuizSessionState, QuizSessionPageArgs>((
      ref,
      args,
    ) {
      final repo = ref.watch(quizPracticeRepositoryProvider);
      final loader = ref.watch(quizSessionLoaderProvider);
      return QuizSessionController(
        repository: repo,
        loader: loader,
        args: args,
      );
    });

class QuizSessionController extends StateNotifier<QuizSessionState> {
  QuizSessionController({
    required QuizPracticeRepository repository,
    required QuizSessionLoader loader,
    required QuizSessionPageArgs args,
  }) : _repository = repository,
       _loader = loader,
       super(QuizSessionState.fromArgs(args)) {
    unawaited(_bootstrap());
  }

  final QuizPracticeRepository _repository;
  final QuizSessionLoader _loader;
  Timer? _autoAdvanceTimer;
  int _resolveToken = 0;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final args = state.args;

    if (args.openCompletionDialog) {
      await _refreshSummariesForCompletion();
      if (!mounted) return;
      state = state.copyWith(loading: false, completionDialogVisible: true);
      return;
    }

    final result = await _loader.load(
      args,
      onPartial: (partial) {
        if (!mounted) return;
        final cached = partial.store.cachedAt(partial.startIndex);
        state = state.copyWith(
          loading: false,
          store: partial.store,
          currentIndex: partial.startIndex,
          currentQuestion: cached,
          currentQuestionLoading: cached == null,
          clearErrorMessage: true,
        );
        if (cached == null) {
          unawaited(_resolveCurrentQuestion(partial.startIndex));
        } else {
          partial.store.prefetchAround(partial.startIndex);
        }
      },
    );
    if (!mounted) return;

    if (!result.isSuccess) {
      state = state.copyWith(
        loading: false,
        currentQuestionLoading: false,
        errorMessage: result.errorMessage,
      );
      return;
    }

    final store = result.store;
    if (store == null || store.totalCount <= 0) {
      state = state.copyWith(
        loading: false,
        store: store,
        currentQuestionLoading: false,
        clearErrorMessage: true,
      );
      return;
    }

    state = state.copyWith(
      loading: false,
      store: store,
      currentIndex: result.startIndex,
      currentQuestion: state.currentIndex == result.startIndex
          ? state.currentQuestion
          : null,
      currentQuestionLoading: state.currentQuestion == null,
      clearErrorMessage: true,
    );
    if (state.currentQuestion == null) {
      unawaited(_resolveCurrentQuestion(result.startIndex));
    } else {
      store.prefetchAround(result.startIndex);
    }
  }

  Future<void> _resolveCurrentQuestion(int index) async {
    final store = state.store;
    if (store == null || index < 0 || index >= store.totalCount) {
      if (!mounted) return;
      state = state.copyWith(currentQuestionLoading: false);
      return;
    }

    final cached = store.cachedAt(index);
    if (cached != null) {
      if (!mounted || state.currentIndex != index) return;
      state = state.copyWith(
        currentQuestion: cached,
        currentQuestionLoading: false,
        clearErrorMessage: true,
      );
      store.prefetchAround(index);
      return;
    }

    final token = ++_resolveToken;
    if (!mounted || state.currentIndex != index) return;
    state = state.copyWith(
      currentQuestion: null,
      currentQuestionLoading: true,
      clearErrorMessage: true,
    );

    try {
      final question = await store.resolveAt(index);
      if (!mounted || token != _resolveToken || state.currentIndex != index) {
        return;
      }
      state = state.copyWith(
        currentQuestion: question,
        currentQuestionLoading: false,
      );
      store.prefetchAround(index);
    } catch (_) {
      if (!mounted || token != _resolveToken || state.currentIndex != index) {
        return;
      }
      state = state.copyWith(
        currentQuestionLoading: false,
        errorMessage: '题目加载失败，请稍后重试',
      );
    }
  }

  Future<void> selectAnswer(int answer) async {
    final store = state.store;
    final question = state.currentQuestion;
    if (store == null || question == null || question.answered) return;

    final index = state.currentIndex;
    final itemId = question.itemId;
    final status = answer == question.correctAnswer ? 1 : 2;
    final response = await _repository.reportAnswer(
      schoolId: state.args.schoolId,
      questionPracticeItemId: itemId,
      answer: answer,
      status: status,
    );
    if (!mounted) return;

    if (!response.isSuccess) {
      state = state.copyWith(errorMessage: response.displayMsg);
      return;
    }

    store.updateAnswer(index: index, userAnswer: answer, status: status);
    final updated = store.cachedAt(index) ?? question.copyWith(
      userAnswer: answer,
      status: status,
    );
    state = state.copyWith(
      currentQuestion: updated,
      revision: state.revision + 1,
      clearErrorMessage: true,
    );

    if (state.autoNext) {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        nextQuestion();
      });
    }
  }

  void previousQuestion() {
    if (state.currentQuestionLoading) {
      state = state.copyWith(errorMessage: '题目加载中，请稍候');
      return;
    }
    final i = state.currentIndex - 1;
    if (i < 0) {
      state = state.copyWith(errorMessage: '已经是第一题了！');
      return;
    }
    _goToIndex(i);
  }

  void nextQuestion() {
    if (state.currentQuestionLoading) {
      state = state.copyWith(errorMessage: '题目加载中，请稍候');
      return;
    }
    final store = state.store;
    if (store == null || store.totalCount <= 0) return;

    final i = state.currentIndex + 1;
    if (i >= store.totalCount) {
      unawaited(_refreshSummariesForCompletion());
      state = state.copyWith(completionDialogVisible: true);
      return;
    }
    _goToIndex(i);
  }

  void _goToIndex(int index) {
    final store = state.store;
    if (store == null) return;

    final cached = store.cachedAt(index);
    state = state.copyWith(
      currentIndex: index,
      currentQuestion: cached,
      currentQuestionLoading: cached == null,
      clearErrorMessage: true,
    );
    if (cached == null) {
      unawaited(_resolveCurrentQuestion(index));
    } else {
      store.prefetchAround(index);
    }
  }

  void setAutoNext(bool value) {
    if (!value) {
      _autoAdvanceTimer?.cancel();
    }
    state = state.copyWith(autoNext: value);
  }

  Future<void> openExitDialog() async {
    await _refreshSummariesForCompletion();
    if (!mounted) return;
    state = state.copyWith(completionDialogVisible: true);
  }

  void closeCompletionDialog() {
    state = state.copyWith(completionDialogVisible: false);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> _refreshSummariesForCompletion() async {
    final response = await _repository.getSummary(
      schoolId: state.args.schoolId,
    );
    if (!mounted || !response.isSuccess || response.data is! Map) return;

    QuizPracticeSummary parse(QuizPracticeType t, Map raw) {
      final node = raw[t.apiKey];
      if (node is! Map) return QuizPracticeSummary.empty(t);
      return QuizPracticeSummary(
        type: t,
        practiceId: _toInt(node['practiceId']),
        allCount: _toInt(node['allCount']) ?? 0,
        doneCount: _toInt(node['doneCount']) ?? 0,
        errorCount: _toInt(node['errorCount']) ?? 0,
        notDoneCount: _toInt(node['notDoneCount']) ?? 0,
        statusInitialized: node['status'] != null,
      );
    }

    final raw = response.data as Map;
    final list = <QuizPracticeSummary>[
      parse(QuizPracticeType.sequence, raw),
      parse(QuizPracticeType.random, raw),
      parse(QuizPracticeType.exam, raw),
      parse(QuizPracticeType.error, raw),
    ];
    state = state.copyWith(summaryAfter: list);
  }

  Future<QuizSessionPageArgs?> switchToRecommended() async {
    final summaries = state.summaryAfter;
    if (summaries.isEmpty) return null;
    final isExam = state.args.practiceType == QuizPracticeType.exam;
    final targetType = isExam ? QuizPracticeType.random : QuizPracticeType.exam;
    QuizPracticeSummary? target;
    for (final s in summaries) {
      if (s.type == targetType) {
        target = s;
        break;
      }
    }
    if (target == null) return null;

    return QuizSessionPageArgs.fromSummary(
      target,
      schoolId: state.args.schoolId,
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
