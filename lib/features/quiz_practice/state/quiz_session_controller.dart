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

    final result = await _loader.load(args);
    if (!mounted) return;

    if (!result.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: result.errorMessage,
      );
      return;
    }

    final questions = result.questions;
    if (questions == null || questions.isEmpty) {
      state = state.copyWith(
        loading: false,
        clearQuestions: true,
      );
      return;
    }

    final startIndex = args.startIndex.clamp(0, questions.length - 1);
    state = state.copyWith(
      loading: false,
      questions: questions,
      currentIndex: startIndex,
      currentQuestion: questions[startIndex],
      clearErrorMessage: true,
    );
  }

  Future<void> selectAnswer(int answer) async {
    final questions = state.questions;
    final question = state.currentQuestion;
    if (questions == null || question == null || question.answered) return;

    final index = state.currentIndex;
    final status = answer == question.correctAnswer ? 1 : 2;
    final response = await _repository.reportAnswer(
      schoolId: state.args.schoolId,
      questionPracticeItemId: question.itemId,
      answer: answer,
      status: status,
    );
    if (!mounted) return;

    if (!response.isSuccess) {
      state = state.copyWith(errorMessage: response.displayMsg);
      return;
    }

    final updated = question.copyWith(userAnswer: answer, status: status);
    final newList = List<QuizQuestion>.of(questions);
    newList[index] = updated;

    state = state.copyWith(
      questions: List<QuizQuestion>.unmodifiable(newList),
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
    final i = state.currentIndex - 1;
    if (i < 0) {
      state = state.copyWith(errorMessage: '已经是第一题了！');
      return;
    }
    _goToIndex(i);
  }

  void nextQuestion() {
    final questions = state.questions;
    if (questions == null || questions.isEmpty) return;

    final i = state.currentIndex + 1;
    if (i >= questions.length) {
      unawaited(_refreshSummariesForCompletion());
      state = state.copyWith(completionDialogVisible: true);
      return;
    }
    _goToIndex(i);
  }

  void _goToIndex(int index) {
    final questions = state.questions;
    if (questions == null || index < 0 || index >= questions.length) return;

    state = state.copyWith(
      currentIndex: index,
      currentQuestion: questions[index],
      clearErrorMessage: true,
    );
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
