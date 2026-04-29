import 'package:flutter/foundation.dart';

enum SmartDictationTrack { absolute, interval, chord }

enum SmartDictationMode { stage, smart }

enum SmartIntervalPlayMode { melodic, harmonic }

@immutable
class SmartDictationLesson {
  const SmartDictationLesson({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.stars,
    required this.pattern,
    required this.optionsRaw,
  });

  final int id;
  final int number;
  final String title;
  final String subtitle;
  final bool unlocked;
  final int stars;
  final String pattern;
  final String optionsRaw;
}

@immutable
class SmartPracticeConfig {
  const SmartPracticeConfig({
    required this.optionPool,
    required this.selectedOptions,
    required this.answerSeconds,
    required this.questionCount,
    this.minNote = '',
    this.maxNote = '',
    this.standardToneEnabled = false,
    this.basicOnly = false,
    this.intervalPlayMode = SmartIntervalPlayMode.melodic,
  });

  final List<String> optionPool;
  final List<String> selectedOptions;
  final int answerSeconds;
  final int questionCount;
  final String minNote;
  final String maxNote;
  final bool standardToneEnabled;
  final bool basicOnly;
  final SmartIntervalPlayMode intervalPlayMode;

  SmartPracticeConfig copyWith({
    List<String>? optionPool,
    List<String>? selectedOptions,
    int? answerSeconds,
    int? questionCount,
    String? minNote,
    String? maxNote,
    bool? standardToneEnabled,
    bool? basicOnly,
    SmartIntervalPlayMode? intervalPlayMode,
  }) {
    return SmartPracticeConfig(
      optionPool: optionPool ?? this.optionPool,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      answerSeconds: answerSeconds ?? this.answerSeconds,
      questionCount: questionCount ?? this.questionCount,
      minNote: minNote ?? this.minNote,
      maxNote: maxNote ?? this.maxNote,
      standardToneEnabled: standardToneEnabled ?? this.standardToneEnabled,
      basicOnly: basicOnly ?? this.basicOnly,
      intervalPlayMode: intervalPlayMode ?? this.intervalPlayMode,
    );
  }
}

@immutable
class SmartPracticeQuestion {
  const SmartPracticeQuestion({
    required this.title,
    required this.playTokens,
    required this.correctOption,
    required this.optionPool,
    required this.harmonic,
  });

  final String title;
  final List<String> playTokens;
  final String correctOption;
  final List<String> optionPool;
  final bool harmonic;
}

@immutable
class SmartPracticeSession {
  const SmartPracticeSession({
    required this.track,
    required this.sourceMode,
    required this.title,
    required this.questions,
    required this.currentIndex,
    required this.correctCount,
    required this.wrongCount,
    required this.remainingMillis,
    required this.answerSeconds,
    required this.running,
    required this.finished,
    required this.showExitDialog,
    required this.linkedLessonId,
    required this.trail,
  });

  final SmartDictationTrack track;
  final SmartDictationMode sourceMode;
  final String title;
  final List<SmartPracticeQuestion> questions;
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final int remainingMillis;
  final int answerSeconds;
  final bool running;
  final bool finished;
  final bool showExitDialog;
  final int linkedLessonId;
  final List<String> trail;

  SmartPracticeQuestion get currentQuestion => questions[currentIndex];

  int get totalQuestions => questions.length;

  bool get timedMode => answerSeconds > 0;

  SmartPracticeSession copyWith({
    SmartDictationTrack? track,
    SmartDictationMode? sourceMode,
    String? title,
    List<SmartPracticeQuestion>? questions,
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    int? remainingMillis,
    int? answerSeconds,
    bool? running,
    bool? finished,
    bool? showExitDialog,
    int? linkedLessonId,
    List<String>? trail,
  }) {
    return SmartPracticeSession(
      track: track ?? this.track,
      sourceMode: sourceMode ?? this.sourceMode,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      remainingMillis: remainingMillis ?? this.remainingMillis,
      answerSeconds: answerSeconds ?? this.answerSeconds,
      running: running ?? this.running,
      finished: finished ?? this.finished,
      showExitDialog: showExitDialog ?? this.showExitDialog,
      linkedLessonId: linkedLessonId ?? this.linkedLessonId,
      trail: trail ?? this.trail,
    );
  }
}

@immutable
class SmartDictationState {
  const SmartDictationState({
    required this.bootstrapping,
    required this.audioLoading,
    required this.audioReady,
    required this.loadingLessons,
    required this.activeTrack,
    required this.activeMode,
    required this.absoluteLessons,
    required this.intervalLessons,
    required this.chordLessons,
    required this.absoluteConfig,
    required this.intervalConfig,
    required this.chordConfig,
    required this.session,
    required this.errorMessage,
    required this.noticeMessage,
    required this.vipExpireDateText,
  });

  final bool bootstrapping;
  final bool audioLoading;
  final bool audioReady;
  final bool loadingLessons;
  final SmartDictationTrack activeTrack;
  final SmartDictationMode activeMode;
  final List<SmartDictationLesson> absoluteLessons;
  final List<SmartDictationLesson> intervalLessons;
  final List<SmartDictationLesson> chordLessons;
  final SmartPracticeConfig absoluteConfig;
  final SmartPracticeConfig intervalConfig;
  final SmartPracticeConfig chordConfig;
  final SmartPracticeSession? session;
  final String errorMessage;
  final String noticeMessage;
  final String vipExpireDateText;

  List<SmartDictationLesson> get activeLessons {
    switch (activeTrack) {
      case SmartDictationTrack.absolute:
        return absoluteLessons;
      case SmartDictationTrack.interval:
        return intervalLessons;
      case SmartDictationTrack.chord:
        return chordLessons;
    }
  }

  SmartPracticeConfig get activeConfig {
    switch (activeTrack) {
      case SmartDictationTrack.absolute:
        return absoluteConfig;
      case SmartDictationTrack.interval:
        return intervalConfig;
      case SmartDictationTrack.chord:
        return chordConfig;
    }
  }

  SmartDictationState copyWith({
    bool? bootstrapping,
    bool? audioLoading,
    bool? audioReady,
    bool? loadingLessons,
    SmartDictationTrack? activeTrack,
    SmartDictationMode? activeMode,
    List<SmartDictationLesson>? absoluteLessons,
    List<SmartDictationLesson>? intervalLessons,
    List<SmartDictationLesson>? chordLessons,
    SmartPracticeConfig? absoluteConfig,
    SmartPracticeConfig? intervalConfig,
    SmartPracticeConfig? chordConfig,
    SmartPracticeSession? session,
    bool clearSession = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
    String? vipExpireDateText,
  }) {
    return SmartDictationState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      audioLoading: audioLoading ?? this.audioLoading,
      audioReady: audioReady ?? this.audioReady,
      loadingLessons: loadingLessons ?? this.loadingLessons,
      activeTrack: activeTrack ?? this.activeTrack,
      activeMode: activeMode ?? this.activeMode,
      absoluteLessons: absoluteLessons ?? this.absoluteLessons,
      intervalLessons: intervalLessons ?? this.intervalLessons,
      chordLessons: chordLessons ?? this.chordLessons,
      absoluteConfig: absoluteConfig ?? this.absoluteConfig,
      intervalConfig: intervalConfig ?? this.intervalConfig,
      chordConfig: chordConfig ?? this.chordConfig,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNoticeMessage
          ? ''
          : (noticeMessage ?? this.noticeMessage),
      vipExpireDateText: vipExpireDateText ?? this.vipExpireDateText,
    );
  }

  static SmartDictationState initial() {
    const absolutePool = <String>[
      'f',
      '#f',
      'g',
      '#g',
      'a',
      'bb',
      'b',
      'c1',
      '#c1',
      'd1',
      'be1',
      'e1',
      'f1',
      '#f1',
      'g1',
      '#g1',
      'a1',
      'bb1',
      'b1',
      'c2',
      '#c2',
      'd2',
      'be2',
      'e2',
      'f2',
      '#f2',
      'g2',
      '#g2',
      'a2',
    ];

    const intervalPool = <String>[
      '纯一度',
      '小二度',
      '大二度',
      '小三度',
      '大三度',
      '纯四度',
      '增四度/减五度',
      '纯五度',
      '小六度',
      '大六度',
      '小七度',
      '大七度',
      '纯八度',
    ];

    const chordPool = <String>[
      '大三和弦',
      '小三和弦',
      '减三和弦',
      '增三和弦',
      '大六和弦',
      '小六和弦',
      '减六和弦',
      '大四六和弦',
      '小四六和弦',
      '减四六和弦',
    ];

    return const SmartDictationState(
      bootstrapping: true,
      audioLoading: false,
      audioReady: false,
      loadingLessons: false,
      activeTrack: SmartDictationTrack.absolute,
      activeMode: SmartDictationMode.stage,
      absoluteLessons: <SmartDictationLesson>[],
      intervalLessons: <SmartDictationLesson>[],
      chordLessons: <SmartDictationLesson>[],
      absoluteConfig: SmartPracticeConfig(
        optionPool: absolutePool,
        selectedOptions: <String>['g', 'a', 'c1', 'd1', 'e1'],
        answerSeconds: 20,
        questionCount: 15,
        minNote: 'f',
        maxNote: 'a2',
        standardToneEnabled: true,
      ),
      intervalConfig: SmartPracticeConfig(
        optionPool: intervalPool,
        selectedOptions: <String>['纯四度', '小三度', '大三度', '纯五度'],
        answerSeconds: 20,
        questionCount: 15,
        minNote: 'f',
        maxNote: 'a2',
        intervalPlayMode: SmartIntervalPlayMode.melodic,
      ),
      chordConfig: SmartPracticeConfig(
        optionPool: chordPool,
        selectedOptions: <String>['大三和弦', '小三和弦', '大六和弦'],
        answerSeconds: 20,
        questionCount: 15,
        minNote: 'f',
        maxNote: 'd2',
        intervalPlayMode: SmartIntervalPlayMode.harmonic,
      ),
      session: null,
      errorMessage: '',
      noticeMessage: '',
      vipExpireDateText: '',
    );
  }
}
