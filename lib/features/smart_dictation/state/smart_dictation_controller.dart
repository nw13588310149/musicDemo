import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/smart_dictation_audio_engine.dart';
import '../data/smart_dictation_repository.dart';
import 'smart_dictation_state.dart';

final smartDictationControllerProvider =
    StateNotifierProvider.autoDispose<
      SmartDictationController,
      SmartDictationState
    >((ref) {
      final repository = ref.watch(smartDictationRepositoryProvider);
      final controller = SmartDictationController(repository: repository);

      ref.onDispose(controller.dispose);
      return controller;
    });

class SmartDictationController extends StateNotifier<SmartDictationState> {
  SmartDictationController({required SmartDictationRepository repository})
    : _repository = repository,
      _audioEngine = SmartDictationAudioEngine(),
      super(SmartDictationState.initial()) {
    _audioBandsSub = _audioEngine.frequencyBands.listen((bands) {
      if (!_disposed && mounted) {
        state = state.copyWith(frequencyBands: bands);
      }
    });
    unawaited(bootstrap());
  }

  final SmartDictationRepository _repository;
  final SmartDictationAudioEngine _audioEngine;
  final Random _random = Random();

  Timer? _timer;
  StreamSubscription<List<double>>? _audioBandsSub;
  bool _disposed = false;
  int _questionElapsedMillis = 0;
  bool _playedFirstSecondCue = false;
  bool _playedFourthSecondCue = false;
  bool _cueInFlight = false;
  bool _resumeAfterExitDialog = false;

  Future<void> bootstrap() async {
    state = state.copyWith(
      bootstrapping: true,
      audioLoading: true,
      clearErrorMessage: true,
      clearNoticeMessage: true,
    );

    try {
      await Future.wait(<Future<void>>[
        _prepareAudio(),
        _loadVipInfo(),
        refreshLessons(),
      ]);
    } catch (_) {
      state = state.copyWith(errorMessage: '智能听写初始化失败，请稍后重试');
    }

    state = state.copyWith(bootstrapping: false);
  }

  Future<void> refreshLessons() async {
    state = state.copyWith(loadingLessons: true, clearErrorMessage: true);
    try {
      final responses = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getSmartDictationList(type: 0),
        _repository.getSmartDictationList(type: 1),
        _repository.getSmartDictationList(type: 2),
      ]);

      final absolute = _parseLessons(responses[0].data);
      final interval = _parseLessons(responses[1].data);
      final chord = _parseLessons(responses[2].data);

      state = state.copyWith(
        loadingLessons: false,
        absoluteLessons: absolute,
        intervalLessons: interval,
        chordLessons: chord,
      );
    } catch (_) {
      state = state.copyWith(
        loadingLessons: false,
        errorMessage: '关卡列表加载失败，请稍后重试',
      );
    }
  }

  Future<void> _prepareAudio() async {
    state = state.copyWith(audioLoading: true);
    try {
      await _audioEngine.ensureInitialized();
      state = state.copyWith(audioLoading: false, audioReady: true);
    } catch (_) {
      state = state.copyWith(
        audioLoading: false,
        audioReady: false,
        errorMessage: '音频引擎初始化失败',
      );
    }
  }

  Future<void> _loadVipInfo() async {
    try {
      final response = await _repository.getMyInfo();
      if (!response.isSuccess || response.data is! Map<String, dynamic>) {
        return;
      }
      final data = response.data as Map<String, dynamic>;
      final user = data['user'];
      if (user is! Map<String, dynamic>) {
        return;
      }
      final raw = user['vipExpireDate']?.toString() ?? '';
      if (raw.isEmpty || raw == 'null') {
        state = state.copyWith(vipExpireDateText: '');
        return;
      }
      final date = DateTime.tryParse(raw);
      if (date == null) {
        return;
      }
      state = state.copyWith(
        vipExpireDateText:
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    } catch (_) {
      // Ignore vip parsing errors.
    }
  }

  void setTrack(SmartDictationTrack track) {
    if (track == state.activeTrack) {
      return;
    }
    state = state.copyWith(
      activeTrack: track,
      clearErrorMessage: true,
      clearNoticeMessage: true,
    );
  }

  void setMode(SmartDictationMode mode) {
    if (mode == state.activeMode) {
      return;
    }
    state = state.copyWith(
      activeMode: mode,
      clearErrorMessage: true,
      clearNoticeMessage: true,
    );
  }

  void toggleOption(String option) {
    final current = List<String>.from(state.activeConfig.selectedOptions);
    if (current.contains(option)) {
      if (current.length <= 1) {
        state = state.copyWith(noticeMessage: '至少保留一个选项');
        return;
      }
      current.remove(option);
    } else {
      current.add(option);
    }
    _updateActiveConfig(state.activeConfig.copyWith(selectedOptions: current));
  }

  void updateAnswerSeconds(int seconds) {
    _updateActiveConfig(state.activeConfig.copyWith(answerSeconds: seconds));
  }

  void updateQuestionCount(int count) {
    _updateActiveConfig(state.activeConfig.copyWith(questionCount: count));
  }

  void updateNoteRange({required String minNote, required String maxNote}) {
    _updateActiveConfig(
      state.activeConfig.copyWith(minNote: minNote, maxNote: maxNote),
    );
  }

  void toggleStandardTone() {
    final config = state.activeConfig;
    _updateActiveConfig(
      config.copyWith(standardToneEnabled: !config.standardToneEnabled),
    );
  }

  void toggleBasicOnly() {
    final config = state.activeConfig;
    _updateActiveConfig(config.copyWith(basicOnly: !config.basicOnly));
  }

  void setIntervalPlayMode(SmartIntervalPlayMode mode) {
    _updateActiveConfig(state.activeConfig.copyWith(intervalPlayMode: mode));
  }

  Future<void> startStageLesson(SmartDictationLesson lesson) async {
    if (!lesson.unlocked) {
      state = state.copyWith(noticeMessage: '该关卡尚未解锁');
      return;
    }

    final options = _parseLessonOptions(lesson, state.activeTrack);
    final questions = _buildQuestions(
      track: state.activeTrack,
      options: options,
      count: state.activeConfig.questionCount,
      mode: SmartDictationMode.stage,
      intervalMode: state.activeConfig.intervalPlayMode,
      basicOnly: state.activeConfig.basicOnly,
      minNote: state.activeConfig.minNote,
      maxNote: state.activeConfig.maxNote,
    );

    if (questions.isEmpty) {
      state = state.copyWith(errorMessage: '该关卡题目异常，暂时无法开始');
      return;
    }
    final audioOk = await _ensureAudioReadyForPlayback(fromUserGesture: true);
    if (!audioOk) {
      return;
    }

    final session = SmartPracticeSession(
      track: state.activeTrack,
      sourceMode: SmartDictationMode.stage,
      title: lesson.title,
      questions: questions,
      currentIndex: 0,
      correctCount: 0,
      wrongCount: 0,
      remainingMillis: state.activeConfig.answerSeconds * 1000,
      answerSeconds: state.activeConfig.answerSeconds,
      running: false,
      started: false,
      finished: false,
      showExitDialog: false,
      linkedLessonId: lesson.id,
      trail: const <String>[],
    );

    _startSession(session);
  }

  Future<void> startSmartPractice() async {
    final config = state.activeConfig;
    final options = List<String>.from(config.selectedOptions)
      ..removeWhere((item) => item.trim().isEmpty);

    if (options.isEmpty) {
      state = state.copyWith(errorMessage: '请至少选择一个练习选项');
      return;
    }

    final questions = _buildQuestions(
      track: state.activeTrack,
      options: options,
      count: config.questionCount,
      mode: SmartDictationMode.smart,
      intervalMode: config.intervalPlayMode,
      basicOnly: config.basicOnly,
      minNote: config.minNote,
      maxNote: config.maxNote,
    );

    if (questions.isEmpty) {
      state = state.copyWith(errorMessage: '题目生成失败，请调整配置后重试');
      return;
    }
    final audioOk = await _ensureAudioReadyForPlayback(fromUserGesture: true);
    if (!audioOk) {
      return;
    }

    final session = SmartPracticeSession(
      track: state.activeTrack,
      sourceMode: SmartDictationMode.smart,
      title: _trackLabel(state.activeTrack),
      questions: questions,
      currentIndex: 0,
      correctCount: 0,
      wrongCount: 0,
      remainingMillis: config.answerSeconds * 1000,
      answerSeconds: config.answerSeconds,
      running: false,
      started: false,
      finished: false,
      showExitDialog: false,
      linkedLessonId: -1,
      trail: const <String>[],
    );

    _startSession(session);
  }

  Future<void> replayCurrentQuestion() async {
    final session = state.session;
    if (session == null || session.finished) {
      return;
    }
    final audioOk = await _ensureAudioReadyForPlayback(fromUserGesture: true);
    if (!audioOk) {
      return;
    }
    await _playQuestionAudioOnly(session.currentQuestion);
  }

  Future<void> submitAnswer(String option) async {
    final session = state.session;
    if (session == null || session.finished) {
      return;
    }

    final correct = session.currentQuestion.correctOption == option;
    final updatedTrail = List<String>.from(session.trail)
      ..add(correct ? 'correct' : 'wrong');

    final lastQuestion = session.currentIndex >= session.totalQuestions - 1;
    if (lastQuestion) {
      final finished = session.copyWith(
        correctCount: correct ? session.correctCount + 1 : session.correctCount,
        wrongCount: correct ? session.wrongCount : session.wrongCount + 1,
        trail: updatedTrail,
        finished: true,
        running: false,
      );
      _stopTimer();
      state = state.copyWith(
        session: finished,
        noticeMessage: correct ? '回答正确' : '回答错误',
      );
      await _saveStageResultIfNeeded(finished);
      return;
    }

    _stopTimer();
    state = state.copyWith(
      session: session.copyWith(
        correctCount: correct ? session.correctCount + 1 : session.correctCount,
        wrongCount: correct ? session.wrongCount : session.wrongCount + 1,
        trail: updatedTrail,
        running: false,
      ),
      noticeMessage: correct ? '回答正确' : '回答错误',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    final latest = state.session;
    if (latest == null ||
        latest.finished ||
        latest.currentIndex != session.currentIndex) {
      return;
    }
    final advanced = latest.copyWith(
      currentIndex: latest.currentIndex + 1,
      remainingMillis: latest.answerSeconds * 1000,
      running: true,
    );
    state = state.copyWith(session: advanced, clearNoticeMessage: true);
    _restartTimer();
  }

  void pauseSession() {
    final session = state.session;
    if (session == null || !session.running || session.finished) {
      return;
    }
    _stopTimer();
    state = state.copyWith(session: session.copyWith(running: false));
  }

  void resumeSession() {
    final session = state.session;
    if (session == null || session.running || session.finished) {
      return;
    }
    final firstStart = !session.started;
    state = state.copyWith(
      session: session.copyWith(running: true, started: true),
    );
    _restartTimer(resetQuestionCue: firstStart);
  }

  void requestLeaveSession() {
    final session = state.session;
    if (session == null || session.finished) {
      return;
    }
    _resumeAfterExitDialog = session.running;
    _stopTimer();
    unawaited(_audioEngine.stopAll());
    state = state.copyWith(
      session: session.copyWith(showExitDialog: true, running: false),
    );
  }

  void cancelLeaveSession() {
    final session = state.session;
    if (session == null) {
      return;
    }
    final resumed = session.copyWith(
      showExitDialog: false,
      running: _resumeAfterExitDialog ? true : session.running,
    );
    state = state.copyWith(session: resumed);
    if (_resumeAfterExitDialog) {
      _restartTimer(resetQuestionCue: false);
    }
    _resumeAfterExitDialog = false;
  }

  void confirmLeaveSession() {
    _stopTimer();
    _resumeAfterExitDialog = false;
    unawaited(_audioEngine.stopAll());
    state = state.copyWith(
      clearSession: true,
      clearNoticeMessage: true,
      clearErrorMessage: true,
    );
  }

  Future<void> restartFinishedSession() async {
    final session = state.session;
    if (session == null || !session.finished) {
      return;
    }
    if (session.sourceMode == SmartDictationMode.stage &&
        session.linkedLessonId > 0) {
      SmartDictationLesson? lesson;
      for (final item in state.activeLessons) {
        if (item.id == session.linkedLessonId) {
          lesson = item;
          break;
        }
      }
      if (lesson != null) {
        await startStageLesson(lesson);
        return;
      }
    }
    await startSmartPractice();
  }

  Future<void> nextAfterFinishedSession() async {
    final session = state.session;
    if (session == null || !session.finished) {
      return;
    }
    if (session.sourceMode == SmartDictationMode.stage &&
        session.linkedLessonId > 0) {
      final lessons = state.activeLessons;
      final currentIndex = lessons.indexWhere(
        (l) => l.id == session.linkedLessonId,
      );
      if (currentIndex >= 0 && currentIndex < lessons.length - 1) {
        final nextLesson = lessons[currentIndex + 1];
        if (nextLesson.unlocked) {
          await startStageLesson(nextLesson);
          return;
        }
      }
      state = state.copyWith(noticeMessage: '已是最后一关');
      return;
    }
    await startSmartPractice();
  }

  Future<void> clearToast() async {
    state = state.copyWith(clearErrorMessage: true, clearNoticeMessage: true);
  }

  Future<void> _startSession(SmartPracticeSession session) async {
    _stopTimer();
    _resetQuestionCueState();
    state = state.copyWith(
      session: session,
      clearErrorMessage: true,
      clearNoticeMessage: true,
    );
    _restartTimer();
  }

  Future<void> _playQuestionAudioOnly(SmartPracticeQuestion question) async {
    final audioOk = await _ensureAudioReadyForPlayback();
    if (!audioOk) {
      return;
    }
    if (question.harmonic) {
      await _audioEngine.playTokensHarmonic(question.playTokens, volume: 0.95);
    } else if (question.playTokens.length <= 1) {
      await _audioEngine.playToken(question.playTokens.first, volume: 0.95);
    } else {
      await _audioEngine.playTokensMelodic(question.playTokens, volume: 0.95);
    }
  }

  void _resetQuestionCueState() {
    _questionElapsedMillis = 0;
    _playedFirstSecondCue = false;
    _playedFourthSecondCue = false;
    _cueInFlight = false;
  }

  Future<bool> _ensureAudioReadyForPlayback({
    bool fromUserGesture = false,
  }) async {
    try {
      if (!state.audioReady) {
        state = state.copyWith(audioLoading: true, clearErrorMessage: true);
        await _audioEngine.ensureInitialized();
      }
      if (fromUserGesture) {
        await _audioEngine.activateByUserGesture();
      }
      if (!state.audioReady || state.audioLoading) {
        state = state.copyWith(audioLoading: false, audioReady: true);
      }
      return true;
    } catch (_) {
      state = state.copyWith(
        audioLoading: false,
        audioReady: false,
        errorMessage: kIsWeb ? 'Web端音频被浏览器拦截，请点击页面后重试' : '音频播放失败，请稍后重试',
      );
      return false;
    }
  }

  void _restartTimer({bool resetQuestionCue = true}) {
    _stopTimer();
    final session = state.session;
    if (session == null ||
        session.finished ||
        !session.running ||
        session.answerSeconds <= 0) {
      return;
    }
    if (resetQuestionCue) {
      _resetQuestionCueState();
    }

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final current = state.session;
      if (current == null || current.finished || !current.running) {
        _stopTimer();
        return;
      }
      _questionElapsedMillis += 100;
      unawaited(_tickQuestionAudioCue(current));

      final remaining = current.remainingMillis - 100;
      if (remaining > 0) {
        state = state.copyWith(
          session: current.copyWith(remainingMillis: remaining),
        );
      } else {
        _stopTimer();
        unawaited(_handleTimeout(current));
      }
    });
  }

  Future<void> _tickQuestionAudioCue(SmartPracticeSession session) async {
    if (_cueInFlight || session.finished) {
      return;
    }
    final shouldPlayStandard =
        session.track == SmartDictationTrack.absolute &&
        state.activeConfig.standardToneEnabled;

    if (!_playedFirstSecondCue && _questionElapsedMillis >= 1000) {
      _playedFirstSecondCue = true;
      _cueInFlight = true;
      try {
        final audioOk = await _ensureAudioReadyForPlayback();
        if (!audioOk) {
          return;
        }
        if (shouldPlayStandard) {
          await _audioEngine.playToken('a1', volume: 0.92);
        } else {
          _playedFourthSecondCue = true;
          await _playQuestionAudioOnly(session.currentQuestion);
        }
      } finally {
        _cueInFlight = false;
      }
      return;
    }

    if (shouldPlayStandard &&
        !_playedFourthSecondCue &&
        _questionElapsedMillis >= 4000) {
      _playedFourthSecondCue = true;
      _cueInFlight = true;
      try {
        await _playQuestionAudioOnly(session.currentQuestion);
      } finally {
        _cueInFlight = false;
      }
    }
  }

  Future<void> _handleTimeout(SmartPracticeSession session) async {
    if (session.finished) {
      return;
    }

    final updatedTrail = List<String>.from(session.trail)..add('timeout');
    final lastQuestion = session.currentIndex >= session.totalQuestions - 1;

    if (lastQuestion) {
      final finished = session.copyWith(
        wrongCount: session.wrongCount + 1,
        trail: updatedTrail,
        finished: true,
        running: false,
        remainingMillis: 0,
      );
      state = state.copyWith(session: finished, noticeMessage: '本题超时');
      await _saveStageResultIfNeeded(finished);
      return;
    }

    state = state.copyWith(
      session: session.copyWith(
        wrongCount: session.wrongCount + 1,
        trail: updatedTrail,
        running: false,
        remainingMillis: 0,
      ),
      noticeMessage: '本题超时',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    final latest = state.session;
    if (latest == null ||
        latest.finished ||
        latest.currentIndex != session.currentIndex) {
      return;
    }
    final advanced = latest.copyWith(
      currentIndex: latest.currentIndex + 1,
      remainingMillis: latest.answerSeconds * 1000,
      running: true,
    );
    state = state.copyWith(session: advanced, clearNoticeMessage: true);
    _restartTimer();
  }

  Future<void> _saveStageResultIfNeeded(SmartPracticeSession session) async {
    if (session.sourceMode != SmartDictationMode.stage ||
        session.linkedLessonId <= 0) {
      return;
    }

    final stars = _resolveStars(
      total: session.totalQuestions,
      correct: session.correctCount,
    );

    try {
      await _repository.saveSmartDictationRecord(
        smartDictationId: session.linkedLessonId,
        stars: stars,
      );
      await _refreshTrackLessons(session.track);
    } catch (_) {
      state = state.copyWith(errorMessage: '成绩保存失败，请稍后重试');
    }
  }

  int _resolveStars({required int total, required int correct}) {
    if (total <= 0) {
      return 0;
    }
    if (correct >= total) {
      return 3;
    }
    if (correct >= (total * 2 / 3).ceil()) {
      return 2;
    }
    if (correct >= (total / 3).ceil()) {
      return 1;
    }
    return 0;
  }

  Future<void> _refreshTrackLessons(SmartDictationTrack track) async {
    final type = switch (track) {
      SmartDictationTrack.absolute => 0,
      SmartDictationTrack.interval => 1,
      SmartDictationTrack.chord => 2,
    };

    try {
      final response = await _repository.getSmartDictationList(type: type);
      final lessons = _parseLessons(response.data);
      switch (track) {
        case SmartDictationTrack.absolute:
          state = state.copyWith(absoluteLessons: lessons);
        case SmartDictationTrack.interval:
          state = state.copyWith(intervalLessons: lessons);
        case SmartDictationTrack.chord:
          state = state.copyWith(chordLessons: lessons);
      }
    } catch (_) {
      // Ignore partial refresh failure.
    }
  }

  List<SmartDictationLesson> _parseLessons(dynamic raw) {
    if (raw is! List) {
      return const <SmartDictationLesson>[];
    }

    final list = <SmartDictationLesson>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final id = _toInt(item['id']);
      final number = _toInt(item['number']);
      final title = _asString(item['title']).isNotEmpty
          ? _asString(item['title'])
          : '第${number == 0 ? list.length + 1 : number}课';
      final subtitle = _asString(item['param4']);
      final unlocked =
          _toBool(item['unlock']) || _toBool(item['unlocked']) || number == 1;
      final stars = _toInt(item['stars']);
      final pattern = _asString(item['param1']);
      final optionsRaw = _asString(item['param2']);

      list.add(
        SmartDictationLesson(
          id: id,
          number: number == 0 ? list.length + 1 : number,
          title: title,
          subtitle: subtitle,
          unlocked: unlocked,
          stars: stars,
          pattern: pattern,
          optionsRaw: optionsRaw,
        ),
      );
    }

    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  List<String> _parseLessonOptions(
    SmartDictationLesson lesson,
    SmartDictationTrack track,
  ) {
    final result = <String>[];

    final fromRaw = lesson.optionsRaw
        .replaceAll('|', ',')
        .replaceAll('，', ',')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    for (final item in fromRaw) {
      final normalized = _normalizeLessonOption(item, track);
      if (normalized.isNotEmpty && !result.contains(normalized)) {
        result.add(normalized);
      }
    }

    if (result.isEmpty && lesson.pattern.isNotEmpty) {
      final patternItems = lesson.pattern
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);
      for (final token in patternItems) {
        if (track == SmartDictationTrack.absolute) {
          final canonical = SmartDictationAudioEngine.canonicalFromToken(token);
          if (canonical.isEmpty) {
            continue;
          }
          final display = _canonicalToDisplayToken(canonical);
          if (!result.contains(display)) {
            result.add(display);
          }
        }
      }
    }

    if (result.isEmpty) {
      // Stage lessons must still be playable even when smart-practice has no
      // default selected options. Fall back to the track's full pool instead
      // of selectedOptions (which is intentionally empty on entry).
      result.addAll(state.activeConfig.optionPool);
    }

    return result;
  }

  String _normalizeLessonOption(String raw, SmartDictationTrack track) {
    if (track == SmartDictationTrack.absolute) {
      final canonical = SmartDictationAudioEngine.canonicalFromToken(raw);
      if (canonical.isEmpty) {
        return '';
      }
      return _canonicalToDisplayToken(canonical);
    }
    return raw
        .replaceAll('<sup>', '')
        .replaceAll('</sup>', '')
        .replaceAll('&nbsp;', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  List<SmartPracticeQuestion> _buildQuestions({
    required SmartDictationTrack track,
    required List<String> options,
    required int count,
    required SmartDictationMode mode,
    required SmartIntervalPlayMode intervalMode,
    required bool basicOnly,
    required String minNote,
    required String maxNote,
  }) {
    final targetCount = count <= 0 ? 15 : count;
    final optionPool = options.toSet().toList(growable: false);

    if (optionPool.isEmpty) {
      return const <SmartPracticeQuestion>[];
    }

    final questions = <SmartPracticeQuestion>[];
    for (var index = 0; index < targetCount; index++) {
      switch (track) {
        case SmartDictationTrack.absolute:
          final correct = optionPool[_random.nextInt(optionPool.length)];
          questions.add(
            SmartPracticeQuestion(
              title: mode == SmartDictationMode.stage ? '关卡听音题' : '绝对音感练习',
              playTokens: <String>[correct],
              correctOption: correct,
              optionPool: optionPool,
              harmonic: false,
            ),
          );
          break;
        case SmartDictationTrack.interval:
          final intervalLabel = optionPool[_random.nextInt(optionPool.length)];
          final semitone = _intervalSemitoneMap[intervalLabel] ?? 0;
          final pair = _buildIntervalPair(
            semitone: semitone,
            basicOnly: basicOnly,
            minNote: minNote,
            maxNote: maxNote,
          );
          if (pair.length < 2) {
            continue;
          }
          questions.add(
            SmartPracticeQuestion(
              title: mode == SmartDictationMode.stage ? '音程识别关卡' : '音程识别练习',
              playTokens: pair,
              correctOption: intervalLabel,
              optionPool: optionPool,
              harmonic: intervalMode == SmartIntervalPlayMode.harmonic,
            ),
          );
          break;
        case SmartDictationTrack.chord:
          final chordLabel = optionPool[_random.nextInt(optionPool.length)];
          final intervals =
              _chordIntervalMap[chordLabel] ?? const <int>[0, 4, 7];
          final notes = _buildChordNotes(
            intervals: intervals,
            basicOnly: basicOnly,
            minNote: minNote,
            maxNote: maxNote,
          );
          if (notes.length < 2) {
            continue;
          }
          questions.add(
            SmartPracticeQuestion(
              title: mode == SmartDictationMode.stage ? '和弦识别关卡' : '和弦识别练习',
              playTokens: notes,
              correctOption: chordLabel,
              optionPool: optionPool,
              harmonic: true,
            ),
          );
          break;
      }
    }

    return questions;
  }

  List<String> _buildIntervalPair({
    required int semitone,
    required bool basicOnly,
    required String minNote,
    required String maxNote,
  }) {
    final range = _resolveCanonicalRange(
      minNote: minNote,
      maxNote: maxNote,
      basicOnly: basicOnly,
    );
    if (range.length < 2) {
      return const <String>[];
    }

    final maxRoot = range.length - 1 - semitone;
    if (maxRoot < 0) {
      return const <String>[];
    }

    final rootIndex = _random.nextInt(maxRoot + 1);
    final root = range[rootIndex];
    final target = range[rootIndex + semitone];
    return <String>[root, target];
  }

  List<String> _buildChordNotes({
    required List<int> intervals,
    required bool basicOnly,
    required String minNote,
    required String maxNote,
  }) {
    final range = _resolveCanonicalRange(
      minNote: minNote,
      maxNote: maxNote,
      basicOnly: basicOnly,
    );
    if (range.length < 3 || intervals.isEmpty) {
      return const <String>[];
    }

    final maxInterval = intervals.reduce(max);
    final maxRoot = range.length - 1 - maxInterval;
    if (maxRoot < 0) {
      return const <String>[];
    }

    final rootIndex = _random.nextInt(maxRoot + 1);
    final notes = <String>[];
    for (final interval in intervals) {
      notes.add(range[rootIndex + interval]);
    }
    return notes;
  }

  List<String> _resolveCanonicalRange({
    required String minNote,
    required String maxNote,
    required bool basicOnly,
  }) {
    final minCanonical = SmartDictationAudioEngine.canonicalFromToken(minNote);
    final maxCanonical = SmartDictationAudioEngine.canonicalFromToken(maxNote);

    final all = _canonicalOrder;
    final start = minCanonical.isEmpty ? 0 : all.indexOf(minCanonical);
    final end =
        maxCanonical.isEmpty ? all.length - 1 : all.indexOf(maxCanonical);

    final safeStart = start < 0 ? 0 : start;
    final safeEnd = end < 0 ? all.length - 1 : end;
    if (safeStart > safeEnd) {
      return basicOnly
          ? all.where((token) => !token.contains('#')).toList(growable: false)
          : all;
    }
    final sliced = all.sublist(safeStart, safeEnd + 1);
    if (!basicOnly) {
      return sliced;
    }
    return sliced.where((token) => !token.contains('#')).toList(growable: false);
  }

  String _canonicalToDisplayToken(String canonical) {
    return _displayTokenByCanonical[canonical] ?? canonical;
  }

  String _trackLabel(SmartDictationTrack track) {
    return switch (track) {
      SmartDictationTrack.absolute => '绝对音感',
      SmartDictationTrack.interval => '音程识别',
      SmartDictationTrack.chord => '和弦识别',
    };
  }

  void _updateActiveConfig(SmartPracticeConfig config) {
    switch (state.activeTrack) {
      case SmartDictationTrack.absolute:
        state = state.copyWith(
          absoluteConfig: config,
          clearErrorMessage: true,
          clearNoticeMessage: true,
        );
      case SmartDictationTrack.interval:
        state = state.copyWith(
          intervalConfig: config,
          clearErrorMessage: true,
          clearNoticeMessage: true,
        );
      case SmartDictationTrack.chord:
        state = state.copyWith(
          chordConfig: config,
          clearErrorMessage: true,
          clearNoticeMessage: true,
        );
    }
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') {
      return '';
    }
    return text;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _stopTimer();
    _audioBandsSub?.cancel();
    unawaited(_audioEngine.dispose());
    super.dispose();
  }
}

const Map<String, int> _intervalSemitoneMap = <String, int>{
  '纯一度': 0,
  '小二度': 1,
  '大二度': 2,
  '小三度': 3,
  '大三度': 4,
  '纯四度': 5,
  '增四度/减五度': 6,
  '纯五度': 7,
  '小六度': 8,
  '大六度': 9,
  '小七度': 10,
  '大七度': 11,
  '纯八度': 12,
};

const Map<String, List<int>> _chordIntervalMap = <String, List<int>>{
  '大三和弦': <int>[0, 4, 7],
  '小三和弦': <int>[0, 3, 7],
  '减三和弦': <int>[0, 3, 6],
  '增三和弦': <int>[0, 4, 8],
  '大六和弦': <int>[0, 4, 9],
  '小六和弦': <int>[0, 3, 9],
  '减六和弦': <int>[0, 3, 8],
  '大四六和弦': <int>[0, 5, 9],
  '小四六和弦': <int>[0, 5, 8],
  '减四六和弦': <int>[0, 5, 7],
};

const List<String> _canonicalOrder = <String>[
  'F3',
  'F#3',
  'G3',
  'G#3',
  'A3',
  'A#3',
  'B3',
  'C4',
  'C#4',
  'D4',
  'D#4',
  'E4',
  'F4',
  'F#4',
  'G4',
  'G#4',
  'A4',
  'A#4',
  'B4',
  'C5',
  'C#5',
  'D5',
  'D#5',
  'E5',
  'F5',
  'F#5',
  'G5',
  'G#5',
  'A5',
  'A#5',
];

const Map<String, String> _displayTokenByCanonical = <String, String>{
  'F3': 'f',
  'F#3': '#f',
  'G3': 'g',
  'G#3': '#g',
  'A3': 'a',
  'A#3': 'bb',
  'B3': 'b',
  'C4': 'c1',
  'C#4': '#c1',
  'D4': 'd1',
  'D#4': 'be1',
  'E4': 'e1',
  'F4': 'f1',
  'F#4': '#f1',
  'G4': 'g1',
  'G#4': '#g1',
  'A4': 'a1',
  'A#4': 'bb1',
  'B4': 'b1',
  'C5': 'c2',
  'C#5': '#c2',
  'D5': 'd2',
  'D#5': 'be2',
  'E5': 'e2',
  'F5': 'f2',
  'F#5': '#f2',
  'G5': 'g2',
  'G#5': '#g2',
  'A5': 'a2',
  'A#5': 'bb2',
};
