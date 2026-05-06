import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../audio/smart_dictation_audio_engine.dart';
import '../state/smart_dictation_controller.dart';
import '../state/smart_dictation_state.dart';

import '../../../core/widgets/app_text.dart';
/// Notes available for the 最低音 picker (matches Figma design).
const _kMinRangeNotes = <String>['f', '#f', 'g', '#g', 'a', 'bb'];

/// Notes available for the 最高音 picker (matches Figma design).
const _kMaxRangeNotes = <String>['f2', '#f2', 'g2', '#g2', 'a2'];

/// Canonical pitch order for absolute-note filtering (matches audio engine).
const _kAbsoluteCanonicalAscending = <String>[
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

int _absoluteCanonicalIndex(String displayToken) {
  final c = SmartDictationAudioEngine.canonicalFromToken(displayToken);
  return _kAbsoluteCanonicalAscending.indexOf(c);
}

/// Full answer grid for practice: all notes in range (absolute) or full pool.
List<String> _practiceDisplayOptions({
  required SmartDictationTrack track,
  required SmartPracticeConfig config,
}) {
  if (track == SmartDictationTrack.absolute) {
    final min = config.minNote.isEmpty ? 'f' : config.minNote;
    final max = config.maxNote.isEmpty ? 'a2' : config.maxNote;
    final iMin = _absoluteCanonicalIndex(min);
    final iMax = _absoluteCanonicalIndex(max);
    if (iMin < 0 || iMax < 0 || iMin > iMax) {
      return List<String>.from(config.optionPool);
    }
    return config.optionPool
        .where((d) {
          final i = _absoluteCanonicalIndex(d);
          return i >= 0 && i >= iMin && i <= iMax;
        })
        .toList(growable: false);
  }
  return List<String>.from(config.optionPool);
}

class SmartDictationV2Page extends ConsumerWidget {
  const SmartDictationV2Page({super.key});

  static const _timeOptions = <int>[7, 10, 15, 20, 25, 30, 0];
  static const _countOptions = <int>[10, 15, 20, 25];
  static const _rangeOptions = <String>[
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartDictationControllerProvider);
    final controller = ref.read(smartDictationControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<SmartDictationState>(smartDictationControllerProvider, (
      prev,
      next,
    ) {
      final error = next.errorMessage;
      if (error.isNotEmpty && error != prev?.errorMessage) {
        _showToast(context, error);
        controller.clearToast();
      }
      final notice = next.noticeMessage;
      if (notice.isNotEmpty && notice != prev?.noticeMessage) {
        // In practice mode, notices are rendered inside timer circle (1.0 behavior).
        if (next.session == null) {
          _showToast(context, notice);
          controller.clearToast();
        }
      }
    });

    final inSession = state.session != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          if (!inSession) ...[
            Container(
              width: ui(180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(ui(16)),
                ),
                border: Border(
                  right: BorderSide(
                    color: const Color(0xFFF3F2F3),
                    width: ui(1),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(ui(8)),
                child: _TrackRail(
                  ui: ui,
                  state: state,
                  onSelect: (track, mode) {
                    controller.setTrack(track);
                    controller.setMode(mode);
                  },
                ),
              ),
            ),
            SizedBox(width: ui(12)),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: inSession ? 0 : ui(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: state.bootstrapping
                        ? const Center(child: CircularProgressIndicator())
                        : _Content(
                            ui: ui,
                            state: state,
                            onStartLesson: controller.startStageLesson,
                            onToggleOption: controller.toggleOption,
                            onSetTime: controller.updateAnswerSeconds,
                            onSetCount: controller.updateQuestionCount,
                            onSetRange: controller.updateNoteRange,
                            onToggleStandard: controller.toggleStandardTone,
                            onToggleBasic: controller.toggleBasicOnly,
                            onSetIntervalMode: controller.setIntervalPlayMode,
                            onStartSmart: controller.startSmartPractice,
                            onSubmit: controller.submitAnswer,
                            onPauseResume: () {
                              final session = state.session;
                              if (session == null) {
                                return;
                              }
                              if (session.running) {
                                controller.pauseSession();
                              } else {
                                controller.resumeSession();
                              }
                            },
                            onLeaveRequest: controller.requestLeaveSession,
                            onLeaveCancel: controller.cancelLeaveSession,
                            onLeaveConfirm: controller.confirmLeaveSession,
                            onRestartFinished:
                                controller.restartFinishedSession,
                            onNextFinished: controller.nextAfterFinishedSession,
                            timeOptions: _timeOptions,
                            countOptions: _countOptions,
                            rangeOptions: _rangeOptions,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showToast(BuildContext context, String message) {
    AppToast.show(
      context,
      message,
      duration: const Duration(milliseconds: 1700),
    );
  }
}

class _TrackRail extends StatelessWidget {
  const _TrackRail({
    required this.ui,
    required this.state,
    required this.onSelect,
  });

  final double Function(num) ui;
  final SmartDictationState state;
  final void Function(SmartDictationTrack, SmartDictationMode) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TrackCard(
          ui: ui,
          title: '绝对音感',
          selectedTrack: state.activeTrack,
          track: SmartDictationTrack.absolute,
          selectedMode: state.activeMode,
          onSelect: onSelect,
        ),
        SizedBox(height: ui(8)),
        _TrackCard(
          ui: ui,
          title: '音程识别',
          selectedTrack: state.activeTrack,
          track: SmartDictationTrack.interval,
          selectedMode: state.activeMode,
          onSelect: onSelect,
        ),
        SizedBox(height: ui(8)),
        _TrackCard(
          ui: ui,
          title: '和弦识别',
          selectedTrack: state.activeTrack,
          track: SmartDictationTrack.chord,
          selectedMode: state.activeMode,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.ui,
    required this.title,
    required this.selectedTrack,
    required this.track,
    required this.selectedMode,
    required this.onSelect,
  });

  final double Function(num) ui;
  final String title;
  final SmartDictationTrack selectedTrack;
  final SmartDictationTrack track;
  final SmartDictationMode selectedMode;
  final void Function(SmartDictationTrack, SmartDictationMode) onSelect;

  @override
  Widget build(BuildContext context) {
    final activeTrack = selectedTrack == track;

    return Container(
      width: double.infinity,
      height: ui(140),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      padding: EdgeInsets.fromLTRB(ui(11), ui(12), ui(11), ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: ui(36),
                height: ui(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(999)),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  AppAssets.smartDictationFigmaIcon,
                  width: ui(18),
                  height: ui(16),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: AppText(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 12 / 13,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          _ModeBtn(
            ui: ui,
            text: '闯关练习',
            selected: activeTrack && selectedMode == SmartDictationMode.stage,
            onTap: () => onSelect(track, SmartDictationMode.stage),
          ),
          SizedBox(height: ui(8)),
          _ModeBtn(
            ui: ui,
            text: '智能练习',
            selected: activeTrack && selectedMode == SmartDictationMode.smart,
            onTap: () => onSelect(track, SmartDictationMode.smart),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  const _ModeBtn({
    required this.ui,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final double Function(num) ui;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: AppText(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6D6B75),
            fontSize: ui(13),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            height: 12 / 13,
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.ui,
    required this.state,
    required this.onStartLesson,
    required this.onToggleOption,
    required this.onSetTime,
    required this.onSetCount,
    required this.onSetRange,
    required this.onToggleStandard,
    required this.onToggleBasic,
    required this.onSetIntervalMode,
    required this.onStartSmart,
    required this.onSubmit,
    required this.onPauseResume,
    required this.onLeaveRequest,
    required this.onLeaveCancel,
    required this.onLeaveConfirm,
    required this.onRestartFinished,
    required this.onNextFinished,
    required this.timeOptions,
    required this.countOptions,
    required this.rangeOptions,
  });

  final double Function(num) ui;
  final SmartDictationState state;
  final ValueChanged<SmartDictationLesson> onStartLesson;
  final ValueChanged<String> onToggleOption;
  final ValueChanged<int> onSetTime;
  final ValueChanged<int> onSetCount;
  final void Function({required String minNote, required String maxNote})
  onSetRange;
  final VoidCallback onToggleStandard;
  final VoidCallback onToggleBasic;
  final ValueChanged<SmartIntervalPlayMode> onSetIntervalMode;
  final VoidCallback onStartSmart;
  final Future<void> Function(String) onSubmit;
  final VoidCallback onPauseResume;
  final VoidCallback onLeaveRequest;
  final VoidCallback onLeaveCancel;
  final VoidCallback onLeaveConfirm;
  final Future<void> Function() onRestartFinished;
  final Future<void> Function() onNextFinished;
  final List<int> timeOptions;
  final List<int> countOptions;
  final List<String> rangeOptions;

  @override
  Widget build(BuildContext context) {
    if (state.session != null) {
      return _PracticeView(
        ui: ui,
        state: state,
        onSubmit: onSubmit,
        onPauseResume: onPauseResume,
        onLeaveRequest: onLeaveRequest,
        onLeaveCancel: onLeaveCancel,
        onLeaveConfirm: onLeaveConfirm,
        onRestartFinished: onRestartFinished,
        onNextFinished: onNextFinished,
      );
    }

    if (state.activeMode == SmartDictationMode.stage) {
      if (state.loadingLessons) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.activeLessons.isEmpty) {
        return Center(
          child: AppText(
            '暂无关卡数据',
            style: TextStyle(color: const Color(0xFFB6B5BB), fontSize: ui(14)),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(14)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const cols = 3;
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - (cols - 1) * ui(spacing)) / cols;
            final cardHeight = ui(100);
            return GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                childAspectRatio: cardWidth / cardHeight,
                mainAxisSpacing: ui(10),
                crossAxisSpacing: ui(spacing),
              ),
              itemCount: state.activeLessons.length,
              itemBuilder: (context, index) {
                final lesson = state.activeLessons[index];
                return _LessonTile(
                  ui: ui,
                  track: state.activeTrack,
                  lesson: lesson,
                  onTap: () => onStartLesson(lesson),
                );
              },
            );
          },
        ),
      );
    }

    final config = state.activeConfig;
    final trackName = switch (state.activeTrack) {
      SmartDictationTrack.absolute => '绝对音感',
      SmartDictationTrack.interval => '音程识别',
      SmartDictationTrack.chord => '和弦识别',
    };
    final isAbsolute = state.activeTrack == SmartDictationTrack.absolute;
    final isInterval = state.activeTrack == SmartDictationTrack.interval;
    final isChord = state.activeTrack == SmartDictationTrack.chord;
    final contentHorizontalPadding = ui(40);
    final optionSpacing = isAbsolute ? ui(12) : ui(20);

    return Column(
      children: [
        // ── scrollable content ──────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: ui(12)),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                contentHorizontalPadding,
                ui(20),
                contentHorizontalPadding,
                ui(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // page title
                  SizedBox(
                    width: double.infinity,
                    child: AppText(
                      '$trackName-智能练习',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(16),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B081A),
                      ),
                    ),
                  ),
                  SizedBox(height: ui(20)),
                  // option grid
                  if (isAbsolute)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const cols = 10;
                        final chipWidth = ui(52);
                        final maxGap = ui(20);
                        final minRowWidth = chipWidth * cols;
                        final available = constraints.maxWidth;
                        final gap = available > minRowWidth
                            ? ((available - minRowWidth) / (cols - 1)).clamp(
                                0.0,
                                maxGap,
                              )
                            : 0.0;
                        final rowWidth = minRowWidth + gap * (cols - 1);

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: rowWidth,
                            child: Wrap(
                              spacing: gap,
                              runSpacing: ui(20),
                              children: [
                                for (final opt in config.optionPool)
                                  _SmartOptionChip(
                                    ui: ui,
                                    label: opt,
                                    isNoteChip: true,
                                    selected: config.selectedOptions.contains(
                                      opt,
                                    ),
                                    onTap: () => onToggleOption(opt),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const cols = 6;
                        final chipWidth = ui(98);
                        final maxGap = optionSpacing;
                        final minRowWidth = chipWidth * cols;
                        final available = constraints.maxWidth;
                        final gap = available > minRowWidth
                            ? ((available - minRowWidth) / (cols - 1)).clamp(
                                0.0,
                                maxGap,
                              )
                            : 0.0;
                        final rowWidth = minRowWidth + gap * (cols - 1);

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: rowWidth,
                            child: Wrap(
                              spacing: gap,
                              runSpacing: ui(20),
                              children: [
                                for (final opt in config.optionPool)
                                  _SmartOptionChip(
                                    ui: ui,
                                    label: opt,
                                    isNoteChip: false,
                                    selected: config.selectedOptions.contains(
                                      opt,
                                    ),
                                    onTap: () => onToggleOption(opt),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  SizedBox(height: ui(36)),
                  // 回答时间
                  _SmartSettingRow(
                    ui: ui,
                    title: '回答时间',
                    children: [
                      for (final s in timeOptions)
                        _SmartRowChip(
                          ui: ui,
                          label: s == 0 ? '无限' : '${s}s',
                          selected: config.answerSeconds == s,
                          onTap: () => onSetTime(s),
                        ),
                    ],
                  ),
                  // absolute-only: 标准音 + 练习题数
                  if (isAbsolute) ...[
                    SizedBox(height: ui(20)),
                    _SmartSettingRow(
                      ui: ui,
                      title: '标准音',
                      toggleValue: config.standardToneEnabled,
                      onToggle: (_) => onToggleStandard(),
                    ),
                    SizedBox(height: ui(20)),
                    _SmartSettingRow(
                      ui: ui,
                      title: '练习题数',
                      children: [
                        for (final c in countOptions)
                          _SmartRowChip(
                            ui: ui,
                            label: '$c题',
                            selected: config.questionCount == c,
                            onTap: () => onSetCount(c),
                          ),
                      ],
                    ),
                  ],
                  // interval / chord: range + mode + count + toggles
                  if (!isAbsolute) ...[
                    SizedBox(height: ui(20)),
                    _SmartSettingRow(
                      ui: ui,
                      title: '最低音',
                      children: [
                        for (final note in _kMinRangeNotes)
                          _SmartRowChip(
                            ui: ui,
                            label: note,
                            isNote: true,
                            selected: config.minNote == note,
                            onTap: () => onSetRange(
                              minNote: note,
                              maxNote: config.maxNote,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    _SmartSettingRow(
                      ui: ui,
                      title: '最高音',
                      children: [
                        for (final note in _kMaxRangeNotes)
                          _SmartRowChip(
                            ui: ui,
                            label: note,
                            isNote: true,
                            selected: config.maxNote == note,
                            onTap: () => onSetRange(
                              minNote: config.minNote,
                              maxNote: note,
                            ),
                          ),
                      ],
                    ),
                    if (isInterval) ...[
                      SizedBox(height: ui(20)),
                      _SmartSettingRow(
                        ui: ui,
                        title: '音程方式',
                        children: [
                          _SmartRowChip(
                            ui: ui,
                            label: '旋律音程',
                            selected:
                                config.intervalPlayMode ==
                                SmartIntervalPlayMode.melodic,
                            onTap: () => onSetIntervalMode(
                              SmartIntervalPlayMode.melodic,
                            ),
                          ),
                          _SmartRowChip(
                            ui: ui,
                            label: '和声音程',
                            selected:
                                config.intervalPlayMode ==
                                SmartIntervalPlayMode.harmonic,
                            onTap: () => onSetIntervalMode(
                              SmartIntervalPlayMode.harmonic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: ui(20)),
                    _SmartSettingRow(
                      ui: ui,
                      title: '练习题数',
                      children: [
                        for (final c in countOptions)
                          _SmartRowChip(
                            ui: ui,
                            label: '$c题',
                            selected: config.questionCount == c,
                            onTap: () => onSetCount(c),
                          ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    _SmartSettingRow(
                      ui: ui,
                      title: '标准音',
                      toggleValue: config.standardToneEnabled,
                      onToggle: (_) => onToggleStandard(),
                    ),
                    if (isInterval || isChord) ...[
                      SizedBox(height: ui(20)),
                      _SmartSettingRow(
                        ui: ui,
                        title: '只练基本音',
                        toggleValue: config.basicOnly,
                        onToggle: (_) => onToggleBasic(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        // ── fixed bottom bar ────────────────────────────────────────────
        // alignment: CRITICAL – gives the child loose constraints so that
        // Container(width:240) is not overridden by the tight full-width
        // constraint propagated from the Column.
        Container(
          height: ui(104),
          color: Colors.white,
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: ui(10)),
          child: GestureDetector(
            onTap: onStartSmart,
            child: Container(
              width: 240,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x59AD80FF),
                    offset: Offset(0, 16),
                    blurRadius: 20,
                  ),
                ],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Image.asset(
                      AppAssets.smartDictationFigmaStartBtnIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AppText(
                    '开始练习',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 28 / 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Practice view – full Figma redesign (node 298:3615 / 315:4011 / 334:4661)
// ─────────────────────────────────────────────────────────────────────────────

class _PracticeView extends StatefulWidget {
  const _PracticeView({
    required this.ui,
    required this.state,
    required this.onSubmit,
    required this.onPauseResume,
    required this.onLeaveRequest,
    required this.onLeaveCancel,
    required this.onLeaveConfirm,
    required this.onRestartFinished,
    required this.onNextFinished,
  });

  final double Function(num) ui;
  final SmartDictationState state;
  final Future<void> Function(String) onSubmit;
  final VoidCallback onPauseResume;
  final VoidCallback onLeaveRequest;
  final VoidCallback onLeaveCancel;
  final VoidCallback onLeaveConfirm;
  final Future<void> Function() onRestartFinished;
  final Future<void> Function() onNextFinished;

  @override
  State<_PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<_PracticeView> {
  final _rng = math.Random();
  late List<double> _bars;
  Timer? _barTimer;
  OverlayEntry? _exitOverlay;
  OverlayEntry? _resultOverlay;
  bool _overlaySyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _bars = List.generate(52, (_) => 0.08 + _rng.nextDouble() * 0.2);
    _barTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      final running = widget.state.session?.running == true;
      setState(() {
        _bars = List.generate(52, (i) {
          final base = running
              ? 0.05 + _rng.nextDouble() * 0.9
              : 0.04 + _rng.nextDouble() * 0.12;
          return (_bars[i] * 0.6 + base * 0.4).clamp(0.04, 1.0);
        });
      });
    });
    // Present the initial exit dialog after first frame if needed.
    _scheduleOverlaySync();
  }

  @override
  void didUpdateWidget(covariant _PracticeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlaySync();
  }

  void _scheduleOverlaySync() {
    if (_overlaySyncScheduled) {
      return;
    }
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      if (!mounted) return;
      _syncExitOverlay();
      _syncResultOverlay();
    });
  }

  void _syncExitOverlay() {
    if (!mounted) {
      return;
    }
    if (_resultOverlay != null) {
      if (_exitOverlay != null) {
        try {
          _exitOverlay!.remove();
        } catch (_) {}
        _exitOverlay = null;
      }
      return;
    }
    final show = widget.state.session?.showExitDialog ?? false;
    if (show && _exitOverlay == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        return;
      }
      final entry = OverlayEntry(
        builder: (_) => _PracticeExitDialog(
          ui: widget.ui,
          onCancel: widget.onLeaveCancel,
          onConfirm: widget.onLeaveConfirm,
        ),
      );
      _exitOverlay = entry;
      overlay.insert(entry);
    } else if (!show && _exitOverlay != null) {
      try {
        _exitOverlay!.remove();
      } catch (_) {}
      _exitOverlay = null;
    }
  }

  void _syncResultOverlay() {
    if (!mounted) {
      return;
    }
    final session = widget.state.session;
    final show = session != null && session.finished;
    if (show && _resultOverlay == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        return;
      }
      final entry = OverlayEntry(
        builder: (_) => _PracticeResultDialog(
          ui: widget.ui,
          session: session,
          onRestart: widget.onRestartFinished,
          onNext: widget.onNextFinished,
        ),
      );
      _resultOverlay = entry;
      overlay.insert(entry);
    } else if (!show && _resultOverlay != null) {
      try {
        _resultOverlay!.remove();
      } catch (_) {}
      _resultOverlay = null;
    }
  }

  @override
  void dispose() {
    _barTimer?.cancel();
    try {
      _exitOverlay?.remove();
    } catch (_) {}
    try {
      _resultOverlay?.remove();
    } catch (_) {}
    _exitOverlay = null;
    _resultOverlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final session = widget.state.session!;
    final isAbsolute = session.track == SmartDictationTrack.absolute;

    final progressFrac = session.totalQuestions == 0
        ? 0.0
        : (session.currentIndex + (session.finished ? 1 : 0)) /
              session.totalQuestions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── header (back + title) ────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), 0),
            child: SizedBox(
              height: ui(32),
              child: Stack(
                children: [
                  // back button
                  GestureDetector(
                    onTap: widget.onLeaveRequest,
                    child: Container(
                      width: ui(32),
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFF3F2F3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Image.asset(
                        AppAssets.smartDictationBack,
                        width: ui(16),
                        height: ui(16),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // title
                  Center(
                    child: AppText(
                      session.title,
                      style: TextStyle(
                        fontSize: ui(16),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B081A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── timer + waveform row ──────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(ui(135), ui(12), ui(135), 0),
            child: SizedBox(
              height: ui(174),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // circular timer
                  _TimerCircle(
                    ui: ui,
                    session: session,
                    noticeMessage: widget.state.noticeMessage,
                  ),
                  SizedBox(width: ui(28)),
                  // waveform
                  Expanded(
                    child: _PracticeAudioVisualizer(
                      ui: ui,
                      frequencyBands: widget.state.frequencyBands,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── progress bar + badge ──────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(ui(135), ui(18), ui(135), 0),
            child: _PracticeProgressBar(
              ui: ui,
              progress: progressFrac,
              current: session.currentIndex + (session.finished ? 1 : 0),
              total: session.totalQuestions,
            ),
          ),

          // ── option chips ──────────────────────────────────────────
          if (!session.finished)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(ui(135), ui(20), ui(135), 0),
                child: _PracticeOptionGrid(
                  ui: ui,
                  state: widget.state,
                  session: session,
                  isAbsolute: isAbsolute,
                  onSubmit: widget.onSubmit,
                ),
              ),
            )
          else
            const Spacer(),

          // ── bottom bar (replay / pause) ────────────────────────────
          _PracticeBottomBar(
            ui: ui,
            session: session,
            onPauseResume: widget.onPauseResume,
          ),
        ],
      ),
    );
  }
}

// ── Circular arc timer ────────────────────────────────────────────────────────

// ── Water-fill timer circle (animated, Figma node 315:4011) ──────────────────

class _TimerCircle extends StatefulWidget {
  const _TimerCircle({
    required this.ui,
    required this.session,
    required this.noticeMessage,
  });

  final double Function(num) ui;
  final SmartPracticeSession session;
  final String noticeMessage;

  @override
  State<_TimerCircle> createState() => _TimerCircleState();
}

class _TimerCircleState extends State<_TimerCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final session = widget.session;
    final notice = widget.noticeMessage;
    final size = ui(174);

    final timedMode = session.timedMode;
    final remainFrac = (timedMode && session.answerSeconds > 0)
        ? (session.remainingMillis / (session.answerSeconds * 1000)).clamp(
            0.0,
            1.0,
          )
        : 1.0;

    final bool isTimeout =
        timedMode && session.remainingMillis <= 0 && !session.finished;
    final bool isReady =
        !session.running &&
        (session.remainingMillis >= session.answerSeconds * 1000 || !timedMode);

    final feedbackText = switch (notice) {
      '回答正确' => '正确',
      '回答错误' => '错误',
      '本题超时' => '超时',
      _ => '',
    };
    final hasFeedback = feedbackText.isNotEmpty;

    final showProgressArc =
        !hasFeedback &&
        timedMode &&
        !isTimeout &&
        !isReady &&
        session.answerSeconds > 0;

    // waterFrac: 0.0 = no water (ready/start), 1.0 = fully filled (timeout)
    final waterFrac = isTimeout
        ? 1.0
        : isReady
        ? 0.0
        : (1.0 - remainFrac).clamp(0.0, 1.0);

    String centerText;
    Color centerTextColor;
    if (hasFeedback) {
      centerText = feedbackText;
      centerTextColor = switch (feedbackText) {
        '正确' => const Color(0xFF00C9A4),
        '错误' => const Color(0xFFE61F62),
        _ => const Color(0xFFFF323C),
      };
    } else if (isTimeout) {
      centerText = '超时';
      centerTextColor = const Color(0xFFFF323C);
    } else if (!timedMode || isReady) {
      centerText = '准备开始';
      centerTextColor = const Color(0xFF0B081A);
    } else {
      final totalSecs = (session.remainingMillis / 1000).ceil();
      final mm = (totalSecs ~/ 60).toString().padLeft(2, '0');
      final ss = (totalSecs % 60).toString().padLeft(2, '0');
      centerText = '$mm:$ss';
      centerTextColor = const Color(0xFF0B081A);
    }

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _WaterTimerPainter(
            waterFrac: waterFrac,
            phase: _ctrl.value * 2 * math.pi,
            isTimeout: isTimeout,
            remainFrac: remainFrac.clamp(0.0, 1.0),
            showProgressArc: showProgressArc,
          ),
          child: Center(
            child: AppText(
              centerText,
              style: TextStyle(
                fontSize: ui(centerText.contains(':') ? 24 : 22),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w600,
                color: centerTextColor,
                letterSpacing:
                    timedMode && !isTimeout && !isReady && !hasFeedback
                    ? 2.4
                    : 0,
                height: 26 / 22,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the layered water-fill circle exactly matching the Figma reference:
///  ① neutral base circle  #F3F2FA
///  ② inner gradient bg    #EDEBFC → #F6F5FC  (or dark when timeout)
///  ③ water fill clipped   animated sine-wave surface
///     • primary wave  – purple  #8741FF → #B68BFF
///     • secondary wave – yellow #F5FF68 (semi-transparent, offset phase)
///  ④ outer gradient ring  #5B4CFF → #F6F5FC  (stroke)
///  ⑤ inset glow
class _WaterTimerPainter extends CustomPainter {
  const _WaterTimerPainter({
    required this.waterFrac,
    required this.phase,
    required this.isTimeout,
    required this.remainFrac,
    required this.showProgressArc,
  });

  final double waterFrac; // 0.0 = empty, 1.0 = fully filled
  final double phase; // wave animation phase in radians
  final bool isTimeout;

  /// Remaining time / total (1.0 = full time left).
  final double remainFrac;
  final bool showProgressArc;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF3F2FA));

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF8741FF), Color(0xFFF6F5FC)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0x70D7D2FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final innerR = r * 0.851;
    final bgGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isTimeout
          ? const <Color>[Color(0xFF6248C8), Color(0xFF4830A8)]
          : const <Color>[Color(0xFFEDEBFC), Color(0xFFF6F5FC)],
    ).createShader(Rect.fromCircle(center: c, radius: innerR));
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..shader = bgGrad
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0),
    );
    canvas.drawCircle(
      c,
      innerR * 0.99,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..color = const Color(0x88D7D2FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      innerR * 0.994,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF2EBFC), Color(0xFFF8F5FC)],
        ).createShader(Rect.fromCircle(center: c, radius: innerR)),
    );
    canvas.drawCircle(
      c,
      innerR * 0.992,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0x40E3D2FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    if (waterFrac > 0.008) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.793)),
      );

      // Water level Y from top: 0.0 = top (full), 1.0 = bottom (empty)
      final levelY = size.height * (1.0 - waterFrac);
      final amp = size.height * 0.052;

      // Secondary wave: yellow, drawn first so purple overlays it.
      if (!isTimeout) {
        canvas.drawPath(
          _wavePath(
            size,
            levelY + amp * 0.48,
            amp * 0.72,
            phase + math.pi * 0.85,
            72,
          ),
          Paint()..color = const Color(0xCCF5FF68),
        );
      }
      // Primary wave: purple gradient fill (must be above yellow).
      canvas.drawPath(
        _wavePath(size, levelY, amp, phase, 72),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isTimeout
                ? const <Color>[Color(0xFF5B4CFF), Color(0xFF8741FF)]
                : const <Color>[Color(0xFF8741FF), Color(0xFFB68BFF)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      canvas.restore();
    }

    canvas.drawCircle(
      c,
      innerR * 0.96,
      Paint()
        ..color = const Color(0x28D7D2FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    if (showProgressArc && remainFrac > 0.002) {
      final arcR = r * 0.925;
      final arcRect = Rect.fromCircle(center: c, radius: arcR);
      final sweep = 2 * math.pi * remainFrac.clamp(0.0, 1.0);
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: <Color>[
            Color(0xFFB68EFF),
            Color(0xFF8741FF),
            Color(0xFF5B4CFF),
            Color(0xFFB68EFF),
          ],
          stops: <double>[0.0, 0.35, 0.7, 1.0],
        ).createShader(arcRect);
      if (remainFrac >= 0.999) {
        canvas.drawCircle(c, arcR, arcPaint);
      } else {
        canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arcPaint);
      }
    }
  }

  /// Builds a closed wave path: bottom rectangle + sine-wave top edge.
  Path _wavePath(
    Size size,
    double levelY,
    double amp,
    double wavePhase,
    int segments,
  ) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(
      size.width,
      levelY + amp * math.sin(wavePhase + size.width * 0.04),
    );
    for (var i = segments; i >= 0; i--) {
      final t = i / segments;
      final x = size.width * t;
      final y = levelY + amp * math.sin(t * math.pi * 5.2 + wavePhase);
      path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_WaterTimerPainter old) =>
      old.waterFrac != waterFrac ||
      old.phase != phase ||
      old.isTimeout != isTimeout ||
      old.remainFrac != remainFrac ||
      old.showProgressArc != showProgressArc;
}

// ── Audio visualizer ─────────────────────────────────────────────────────────
// Bars are styled to match music_play (purple gradient, mirrored fade), but
// driven by the real frequencyBands stream from SmartDictationAudioEngine
// (SoLoud FFT on native / Web Audio AnalyserNode on the web build).
//
// Two smart-dictation specific touches sit on top of the music_play style:
//   • Active bands are re-centered horizontally so a single piano tone (whose
//     energy is concentrated in the low-frequency bins) reads as a centered
//     "swell" rather than a left-aligned cluster.
//   • Decorative music-note / spark glyphs hover above and below the waveform
//     and pulse together with playback, matching the original Figma design.

class _PracticeAudioVisualizer extends StatelessWidget {
  const _PracticeAudioVisualizer({
    required this.ui,
    required this.frequencyBands,
  });

  final double Function(num) ui;
  final List<double> frequencyBands;

  @override
  Widget build(BuildContext context) {
    final height = ui(70);
    final playing = frequencyBands.isNotEmpty;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: playing
                  ? CustomPaint(
                      painter: _PracticeFrequencyPainter(
                        frequencyBands: frequencyBands,
                        time: 0,
                        playing: true,
                      ),
                    )
                  : CustomPaint(
                      painter: _PracticeFrequencyPainter(
                        frequencyBands: const <double>[],
                        time: 0,
                        playing: false,
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -ui(16),
            height: ui(24),
            child: const IgnorePointer(
              child: _PracticeFrequencyDecorations(
                position: _PracticeDecorationPosition.top,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -ui(14),
            height: ui(22),
            child: const IgnorePointer(
              child: _PracticeFrequencyDecorations(
                position: _PracticeDecorationPosition.bottom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-centers a frequency-band list so its non-zero region sits in the middle
/// of the output, padding the rest with zeros. Used to keep single-tone
/// piano spectra visually centered instead of clinging to the left edge.
List<double> _centerFrequencyBands(List<double> bands) {
  const targetCount = 46;
  if (bands.isEmpty) {
    return const <double>[];
  }
  final source = bands.length == targetCount
      ? bands
      : List<double>.generate(
          targetCount,
          (i) =>
              bands[(i * bands.length / targetCount).floor().clamp(
                0,
                bands.length - 1,
              )],
        );

  var first = 0;
  var last = source.length - 1;
  while (first < source.length && source[first] <= 0.018) {
    first++;
  }
  while (last >= first && source[last] <= 0.018) {
    last--;
  }
  if (first > last) {
    return List<double>.filled(targetCount, 0);
  }

  final active = source.sublist(first, last + 1);
  final result = List<double>.filled(targetCount, 0);
  final offset = ((targetCount - active.length) / 2).round().clamp(
    0,
    targetCount - 1,
  );
  for (var i = 0; i < active.length && offset + i < targetCount; i++) {
    final envelope = math.sin((i + 1) / (active.length + 1) * math.pi);
    result[offset + i] = math.max(
      active[i],
      active[i] * 0.72 + envelope * 0.08,
    );
  }
  return result;
}

class _PracticeFrequencyPainter extends CustomPainter {
  const _PracticeFrequencyPainter({
    required this.frequencyBands,
    required this.time,
    required this.playing,
  });

  final List<double> frequencyBands;
  final double time;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final centered = _centerFrequencyBands(frequencyBands);
    final count = centered.isEmpty ? 46 : centered.length;
    const gap = 3.0;
    final barWidth = math.max(1.2, (size.width - gap * (count - 1)) / count);
    final centerY = size.height * 0.62;
    final maxUp = size.height * 0.58;
    final maxDown = size.height * 0.30;
    final radius = Radius.circular(barWidth / 2);
    final idlePaint = Paint()..color = const Color(0xFFE4E1EC);

    for (var i = 0; i < count; i++) {
      final raw = centered.isEmpty
          ? (playing ? _fallbackLevel(i, count, time) : 0.0)
          : centered[i];
      final level = raw.clamp(0.0, 1.0);
      final x = i * (barWidth + gap);
      final up = math.max(size.height * 0.08, maxUp * level);
      final down = math.max(size.height * 0.03, maxDown * level);
      final active = level > 0.015;

      final topRect = Rect.fromLTRB(x, centerY - up, x + barWidth, centerY);
      final topPaint = active
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF8741FF), Color(0xFFC8AEFF)],
              ).createShader(topRect))
          : idlePaint;
      canvas.drawRRect(RRect.fromRectAndRadius(topRect, radius), topPaint);

      final bottomRect = Rect.fromLTRB(
        x,
        centerY,
        x + barWidth,
        centerY + down,
      );
      final bottomPaint = active
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x668741FF), Color(0x00C8AEFF)],
              ).createShader(bottomRect))
          : idlePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bottomRect, radius),
        bottomPaint,
      );
    }
  }

  double _fallbackLevel(int index, int count, double t) {
    final phase = t * math.pi * 2;
    final waveA = math.sin(phase * 1.4 + index * 0.52);
    final waveB = math.sin(phase * 2.1 + index * 0.21);
    final envelope = math.sin(index / (count - 1) * math.pi);
    return (0.18 + (waveA * 0.18 + waveB * 0.12 + 0.30) * envelope).clamp(
      0.04,
      0.88,
    );
  }

  @override
  bool shouldRepaint(covariant _PracticeFrequencyPainter oldDelegate) {
    return oldDelegate.frequencyBands != frequencyBands ||
        oldDelegate.time != time ||
        oldDelegate.playing != playing;
  }
}

enum _PracticeDecorationPosition { top, bottom }

/// Decorative pulsing music-note / spark glyphs that surround the waveform.
/// They always bob and twinkle at a constant intensity, regardless of whether
/// audio is currently playing — the goal is a lively backdrop, not a status
/// indicator.
class _PracticeFrequencyDecorations extends StatefulWidget {
  const _PracticeFrequencyDecorations({required this.position});

  final _PracticeDecorationPosition position;

  @override
  State<_PracticeFrequencyDecorations> createState() =>
      _PracticeFrequencyDecorationsState();
}

class _PracticeFrequencyDecorationsState
    extends State<_PracticeFrequencyDecorations>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PracticeDecorationPainter(
              position: widget.position,
              time: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _PracticeDecorationPainter extends CustomPainter {
  const _PracticeDecorationPainter({
    required this.position,
    required this.time,
  });

  final _PracticeDecorationPosition position;
  final double time;

  // Sparse, intentionally irregular layout — the x positions, vertical
  // offsets, sizes, motion phases and twinkle phases are all hand-chosen
  // (not evenly spaced) so the glyphs feel scattered rather than gridded.
  static const _topGlyphs = <_DecorationGlyph>[
    _DecorationGlyph(
      x: 0.13,
      yBias: 0.55,
      kind: _GlyphKind.eighthNote,
      size: 11,
      motionPhase: 0.0,
      twinklePhase: 0.6,
    ),
    _DecorationGlyph(
      x: 0.47,
      yBias: 0.30,
      kind: _GlyphKind.sparkle,
      size: 5.0,
      motionPhase: 1.3,
      twinklePhase: 2.1,
    ),
    _DecorationGlyph(
      x: 0.83,
      yBias: 0.65,
      kind: _GlyphKind.beamedNote,
      size: 12,
      motionPhase: 2.4,
      twinklePhase: 0.0,
    ),
  ];

  static const _bottomGlyphs = <_DecorationGlyph>[
    _DecorationGlyph(
      x: 0.27,
      yBias: 0.55,
      kind: _GlyphKind.sparkle,
      size: 4.6,
      motionPhase: 0.5,
      twinklePhase: 1.4,
    ),
    _DecorationGlyph(
      x: 0.69,
      yBias: 0.40,
      kind: _GlyphKind.eighthNote,
      size: 10,
      motionPhase: 1.9,
      twinklePhase: 3.0,
    ),
    _DecorationGlyph(
      x: 0.92,
      yBias: 0.70,
      kind: _GlyphKind.dot,
      size: 2.0,
      motionPhase: 3.1,
      twinklePhase: 0.8,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final glyphs = position == _PracticeDecorationPosition.top
        ? _topGlyphs
        : _bottomGlyphs;
    final phase = time * math.pi * 2;

    for (final glyph in glyphs) {
      final wobble = math.sin(phase + glyph.motionPhase);
      final twinkle = (0.5 + 0.5 * math.sin(phase * 1.4 + glyph.twinklePhase))
          .clamp(0.0, 1.0)
          .toDouble();
      final dy = wobble * size.height * 0.22;
      final cx = size.width * glyph.x;
      final cy = size.height * glyph.yBias + dy;
      final alpha = (0.55 + 0.45 * twinkle).clamp(0.0, 1.0);
      _paintGlyph(canvas, Offset(cx, cy), glyph, alpha);
    }
  }

  void _paintGlyph(
    Canvas canvas,
    Offset center,
    _DecorationGlyph glyph,
    double alpha,
  ) {
    switch (glyph.kind) {
      case _GlyphKind.dot:
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFB68EFF).withValues(alpha: alpha);
        canvas.drawCircle(center, glyph.size, paint);
        break;
      case _GlyphKind.sparkle:
        _paintSparkle(canvas, center, glyph.size, alpha);
        break;
      case _GlyphKind.eighthNote:
        _paintEighthNote(canvas, center, glyph.size, alpha);
        break;
      case _GlyphKind.beamedNote:
        _paintBeamedNote(canvas, center, glyph.size, alpha);
        break;
    }
  }

  void _paintSparkle(Canvas canvas, Offset center, double size, double alpha) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = const Color(0xFFF5FF68).withValues(alpha: alpha);
    final r = size;
    canvas.drawLine(
      Offset(center.dx - r, center.dy),
      Offset(center.dx + r, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - r),
      Offset(center.dx, center.dy + r),
      paint,
    );
    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF8741FF).withValues(alpha: alpha * 0.6);
    canvas.drawCircle(center, math.max(1.0, size * 0.32), glow);
  }

  void _paintEighthNote(
    Canvas canvas,
    Offset center,
    double size,
    double alpha,
  ) {
    final color = const Color(0xFF8741FF).withValues(alpha: alpha);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size * 0.14)
      ..strokeCap = StrokeCap.round
      ..color = color;

    final headWidth = size * 0.55;
    final headHeight = size * 0.42;
    final headCenter = Offset(center.dx - size * 0.18, center.dy + size * 0.34);
    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(-0.32);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: headWidth,
        height: headHeight,
      ),
      paint,
    );
    canvas.restore();

    final stemTop = Offset(center.dx + size * 0.04, center.dy - size * 0.55);
    final stemBottom = Offset(headCenter.dx + size * 0.20, headCenter.dy);
    canvas.drawLine(stemTop, stemBottom, stroke);

    final flag = Path()
      ..moveTo(stemTop.dx, stemTop.dy)
      ..quadraticBezierTo(
        stemTop.dx + size * 0.55,
        stemTop.dy + size * 0.05,
        stemTop.dx + size * 0.32,
        stemTop.dy + size * 0.46,
      );
    canvas.drawPath(flag, stroke);
  }

  void _paintBeamedNote(
    Canvas canvas,
    Offset center,
    double size,
    double alpha,
  ) {
    final color = const Color(0xFFB68EFF).withValues(alpha: alpha);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = color;
    final beam = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final headHeight = size * 0.36;
    final headWidth = size * 0.46;
    final leftHead = Offset(center.dx - size * 0.36, center.dy + size * 0.32);
    final rightHead = Offset(center.dx + size * 0.20, center.dy + size * 0.32);

    for (final head in <Offset>[leftHead, rightHead]) {
      canvas.save();
      canvas.translate(head.dx, head.dy);
      canvas.rotate(-0.28);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: headWidth,
          height: headHeight,
        ),
        paint,
      );
      canvas.restore();
    }

    final leftStemTop = Offset(
      leftHead.dx + size * 0.18,
      center.dy - size * 0.50,
    );
    final leftStemBottom = Offset(leftHead.dx + size * 0.18, leftHead.dy);
    final rightStemTop = Offset(
      rightHead.dx + size * 0.18,
      center.dy - size * 0.50,
    );
    final rightStemBottom = Offset(rightHead.dx + size * 0.18, rightHead.dy);
    canvas.drawLine(leftStemTop, leftStemBottom, stroke);
    canvas.drawLine(rightStemTop, rightStemBottom, stroke);

    final beamRect = Rect.fromLTRB(
      leftStemTop.dx,
      leftStemTop.dy,
      rightStemTop.dx,
      leftStemTop.dy + size * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beamRect, Radius.circular(size * 0.08)),
      beam,
    );
  }

  @override
  bool shouldRepaint(covariant _PracticeDecorationPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.position != position;
  }
}

enum _GlyphKind { dot, sparkle, eighthNote, beamedNote }

class _DecorationGlyph {
  const _DecorationGlyph({
    required this.x,
    required this.yBias,
    required this.kind,
    required this.size,
    required this.motionPhase,
    required this.twinklePhase,
  });

  /// Horizontal position as a fraction of the available width (0..1).
  final double x;

  /// Vertical anchor as a fraction of the available height (0..1).
  /// Each glyph picks a slightly different bias so they don't sit on a line.
  final double yBias;

  final _GlyphKind kind;
  final double size;

  /// Phase offset for the up/down bobbing motion.
  final double motionPhase;

  /// Phase offset for the twinkle / opacity oscillation.
  final double twinklePhase;
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _PracticeProgressBar extends StatelessWidget {
  const _PracticeProgressBar({
    required this.ui,
    required this.progress,
    required this.current,
    required this.total,
  });

  final double Function(num) ui;
  final double progress;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final trackW = c.maxWidth;
        final p = progress.clamp(0.0, 1.0);
        final tipX = trackW * p;
        final trackH = ui(4);
        final badgeH = ui(26);
        final badgeMinW = ui(48);
        final label = '$current/$total';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final horizPad = ui(10);
        final badgeW = math.max(badgeMinW, tp.width + horizPad * 2);
        // Pill's right edge aligns with the filled progress tip (Figma).
        var left = tipX - badgeW;
        if (left < 0) {
          left = 0;
        } else if (left + badgeW > trackW) {
          left = trackW - badgeW;
        }

        final stackH = ui(32);
        final badgeTop = (stackH - badgeH) / 2;

        return SizedBox(
          height: stackH,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(trackH / 2),
                  child: SizedBox(
                    width: trackW,
                    height: trackH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFFECECF1)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: tipX.clamp(0.0, trackW),
                            height: trackH,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Color(0xFFFFFFFF),
                                    Color(0xFFE2D0FF),
                                    Color(0xFFC9A8FF),
                                    Color(0xFF8741FF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: badgeTop,
                child: Container(
                  width: badgeW,
                  height: badgeH,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8741FF),
                    borderRadius: BorderRadius.circular(badgeH / 2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0x408741FF),
                        offset: Offset(0, ui(4)),
                        blurRadius: ui(10),
                      ),
                    ],
                  ),
                  child: AppText(
                    label,
                    style: TextStyle(
                      fontSize: ui(12),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Option chips grid ─────────────────────────────────────────────────────────

class _PracticeOptionGrid extends StatelessWidget {
  const _PracticeOptionGrid({
    required this.ui,
    required this.state,
    required this.session,
    required this.isAbsolute,
    required this.onSubmit,
  });

  final double Function(num) ui;
  final SmartDictationState state;
  final SmartPracticeSession session;
  final bool isAbsolute;
  final Future<void> Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    final displayOptions = _practiceDisplayOptions(
      track: session.track,
      config: state.activeConfig,
    );
    final playable = session.currentQuestion.optionPool.toSet();
    final answerEnabled = session.started;

    if (isAbsolute) {
      // fixed 10-per-row layout (same logic as config screen)
      return LayoutBuilder(
        builder: (context, constraints) {
          const cols = 10;
          final chipW = ui(52);
          final maxGap = ui(20);
          final minRowW = chipW * cols;
          final available = constraints.maxWidth;
          final gap = available > minRowW
              ? ((available - minRowW) / (cols - 1)).clamp(0.0, maxGap)
              : 0.0;
          final rowW = minRowW + gap * (cols - 1);

          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: rowW,
              child: Wrap(
                spacing: gap,
                runSpacing: ui(20),
                children: [
                  for (final opt in displayOptions)
                    _SmartOptionChip(
                      ui: ui,
                      label: opt,
                      isNoteChip: true,
                      selected: playable.contains(opt),
                      enabled: answerEnabled && playable.contains(opt),
                      onTap: () => onSubmit(opt),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    // interval / chord – 6-per-row layout
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 6;
        final chipW = ui(98);
        final maxGap = ui(20);
        final minRowW = chipW * cols;
        final available = constraints.maxWidth;
        final gap = available > minRowW
            ? ((available - minRowW) / (cols - 1)).clamp(0.0, maxGap)
            : 0.0;
        final rowW = minRowW + gap * (cols - 1);

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: rowW,
            child: Wrap(
              spacing: gap,
              runSpacing: ui(20),
              children: [
                for (final opt in displayOptions)
                  _SmartOptionChip(
                    ui: ui,
                    label: opt,
                    isNoteChip: false,
                    selected: playable.contains(opt),
                    enabled: answerEnabled && playable.contains(opt),
                    onTap: () => onSubmit(opt),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _PracticeBottomBar extends StatelessWidget {
  const _PracticeBottomBar({
    required this.ui,
    required this.session,
    required this.onPauseResume,
  });

  final double Function(num) ui;
  final SmartPracticeSession session;
  final VoidCallback onPauseResume;

  @override
  Widget build(BuildContext context) {
    final isInitial = !session.started && !session.running;
    final label = isInitial
        ? '开始练习'
        : session.running
        ? '暂停'
        : '继续';

    return Container(
      height: ui(94),
      color: Colors.white,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: ui(10)),
      child: GestureDetector(
        onTap: onPauseResume,
        child: Container(
          width: ui(240),
          height: ui(52),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
            ),
            borderRadius: BorderRadius.circular(ui(12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0x59AD80FF),
                offset: Offset(0, ui(16)),
                blurRadius: ui(20),
              ),
            ],
          ),
          padding: EdgeInsets.all(ui(10)),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isInitial)
                Image.asset(
                  AppAssets.smartDictationStart,
                  width: ui(24),
                  height: ui(24),
                  fit: BoxFit.contain,
                )
              else
                Icon(
                  session.running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: ui(24),
                  color: Colors.white,
                ),
              SizedBox(width: ui(8)),
              AppText(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 28 / 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeResultDialog extends StatelessWidget {
  const _PracticeResultDialog({
    required this.ui,
    required this.session,
    required this.onRestart,
    required this.onNext,
  });

  final double Function(num) ui;
  final SmartPracticeSession session;
  final Future<void> Function() onRestart;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final total = session.totalQuestions <= 0 ? 1 : session.totalQuestions;
    final attempts = session.correctCount + session.wrongCount;
    final rate = attempts <= 0
        ? 0
        : ((session.correctCount / attempts) * 100).round().clamp(0, 100);
    final stars = session.correctCount >= total
        ? 3
        : session.correctCount >= (total * 2 / 3).ceil()
        ? 2
        : session.correctCount >= (total / 3).ceil()
        ? 1
        : 0;

    // 设计稿 1180×820 画布中卡片 (459,247) 尺寸 428×260；以下坐标已换算为相对卡片左上角。
    const double kCardLeft = 459;
    const double kCardTop = 247;
    double rx(double designLeft) => designLeft - kCardLeft;
    double ry(double designTop) => designTop - kCardTop;

    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.8)),
          ),
          Center(
            child: SizedBox(
              width: ui(428),
              height: ui(260),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // 主卡片：渐变 + 圆角投影（图2）
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ui(24)),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: <double>[0.0, 0.58, 1.0],
                          colors: <Color>[
                            Color(0xFFD2C6FF),
                            Colors.white,
                            Colors.white,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0x400B081A),
                            offset: Offset(0, ui(12)),
                            blurRadius: ui(28),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 光球 qiu.png：设计稿 (558,132) 相对卡片 (99,-115)
                  Positioned(
                    left: ui(rx(558)),
                    top: ui(ry(132)),
                    child: IgnorePointer(
                      child: Image.asset(
                        AppAssets.smartDictationFigmaResultGlow,
                        width: ui(230),
                        height: ui(230),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // 彩带 caidai.png：(504,89)
                  Positioned(
                    left: ui(rx(504)),
                    top: ui(ry(89)),
                    child: IgnorePointer(
                      child: Image.asset(
                        AppAssets.smartDictationFigmaResultRibbon,
                        width: ui(326),
                        height: ui(326),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // 三星：水平居中、微弧线，中间略大且更高（图2）
                  Positioned(
                    left: ui(126),
                    top: ui(-18),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: stars >= 1 ? 1 : 0,
                        child: Image.asset(
                          AppAssets.smartDictationFigmaResultStar1,
                          width: ui(64),
                          height: ui(64),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: ui(175),
                    top: ui(-30),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: stars >= 2 ? 1 : 0,
                        child: Image.asset(
                          AppAssets.smartDictationFigmaResultStar2,
                          width: ui(78),
                          height: ui(78),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: ui(238),
                    top: ui(-18),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: stars >= 3 ? 1 : 0,
                        child: Image.asset(
                          AppAssets.smartDictationFigmaResultStar3,
                          width: ui(64),
                          height: ui(64),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: ui(24),
                    right: ui(24),
                    top: ui(52),
                    child: AppText(
                      '太棒了！恭喜完成本课',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(24),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B081A),
                        height: 28 / 24,
                      ),
                    ),
                  ),
                  Positioned(
                    left: ui(rx(504.43)),
                    top: ui(ry(330)),
                    child: _ResultStatCard(
                      ui: ui,
                      title: '答对数量',
                      value: '${session.correctCount}个',
                    ),
                  ),
                  Positioned(
                    left: ui(rx(622.43)),
                    top: ui(ry(330)),
                    child: _ResultStatCard(
                      ui: ui,
                      title: '错误数量',
                      value: '${session.wrongCount}个',
                      valueColor: const Color(0xFFFF323C),
                    ),
                  ),
                  Positioned(
                    left: ui(rx(740.43)),
                    top: ui(ry(330)),
                    child: _ResultStatCard(
                      ui: ui,
                      title: '正确率',
                      value: '$rate%',
                    ),
                  ),
                  Positioned(
                    left: ui(rx(483.43)),
                    top: ui(ry(423)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ResultActionButton(
                          ui: ui,
                          text: '重新练习',
                          onTap: onRestart,
                        ),
                        SizedBox(width: ui(16)),
                        _ResultActionButton(
                          ui: ui,
                          text: '下一关',
                          primary: true,
                          onTap: onNext,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStatCard extends StatelessWidget {
  const _ResultStatCard({
    required this.ui,
    required this.title,
    required this.value,
    this.valueColor = const Color(0xFF0B081A),
  });

  final double Function(num) ui;
  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(102),
        height: ui(71),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: ui(6),
              top: ui(22),
              child: Container(
                width: ui(91),
                height: ui(43),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(6)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0x140B081A),
                      offset: Offset(0, ui(2)),
                      blurRadius: ui(6),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui(27),
              top: ui(6),
              right: ui(6),
              child: AppText(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6D6B75),
                  height: 12 / 12,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: ui(32),
              child: AppText(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(16),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                  height: 24 / 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultActionButton extends StatelessWidget {
  const _ResultActionButton({
    required this.ui,
    required this.text,
    required this.onTap,
    this.primary = false,
  });

  final double Function(num) ui;
  final String text;
  final Future<void> Function() onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(ui(12));
    if (!primary) {
      return GestureDetector(
        onTap: () => onTap(),
        child: Container(
          width: ui(182),
          height: ui(45),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            border: Border.all(color: const Color(0xFFF3F2F3), width: 2),
          ),
          alignment: Alignment.center,
          child: AppText(
            text,
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 12 / 16,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        width: ui(182),
        height: ui(45),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: <double>[0.0, 0.42, 1.0],
            colors: <Color>[
              Color(0xFFD2BAFF),
              Color(0xFF9F6AFF),
              Color(0xFF8640FF),
            ],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x59AD80FF),
              offset: Offset(0, 16),
              blurRadius: 20,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: ui(4),
              right: ui(4),
              height: ui(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ui(12)),
                    topRight: Radius.circular(ui(12)),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.38),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            AppText(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 12 / 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exit confirmation dialog ──────────────────────────────────────────────────

class _PracticeExitDialog extends StatelessWidget {
  const _PracticeExitDialog({
    required this.ui,
    required this.onCancel,
    required this.onConfirm,
  });

  final double Function(num) ui;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // full-app dim backdrop
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.78)),
            ),
          ),
          // dialog card
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: ui(420),
                height: ui(218),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(24)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: <double>[0.0, 0.46, 1.0],
                    colors: <Color>[
                      Color(0xFFD2C6FF),
                      Colors.white,
                      Colors.white,
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(24)),
                  child: Stack(
                    children: [
                      Positioned(
                        left: ui(168),
                        top: -ui(11),
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (Rect rect) {
                            return const LinearGradient(
                              begin: Alignment(-0.85, -0.95),
                              end: Alignment(0.95, 1.0),
                              colors: <Color>[
                                Color(0x00000000),
                                Color(0x22000000),
                                Color(0x70000000),
                                Color(0xA0000000),
                              ],
                              stops: <double>[0.0, 0.28, 0.66, 1.0],
                            ).createShader(rect);
                          },
                          child: Opacity(
                            opacity: 0.56,
                            child: Image.asset(
                              AppAssets.smartDictationFigmaExitTopImage,
                              width: ui(288),
                              height: ui(164),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: ui(62),
                        left: 0,
                        right: 0,
                        child: AppText(
                          '是否退出当前练习',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: ui(24),
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0B081A),
                            height: 12 / 24,
                          ),
                        ),
                      ),
                      Positioned(
                        left: ui(20),
                        top: ui(136),
                        child: SizedBox(
                          width: ui(182),
                          child: _ExitDialogButton(
                            ui: ui,
                            label: '取消',
                            onTap: onCancel,
                          ),
                        ),
                      ),
                      Positioned(
                        left: ui(218),
                        top: ui(136),
                        child: SizedBox(
                          width: ui(182),
                          child: _ExitDialogButton(
                            ui: ui,
                            label: '确认',
                            primary: true,
                            onTap: onConfirm,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitDialogButton extends StatelessWidget {
  const _ExitDialogButton({
    required this.ui,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final double Function(num) ui;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(45),
        decoration: BoxDecoration(
          color: primary ? null : Colors.white,
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          borderRadius: BorderRadius.circular(ui(12)),
          border: primary
              ? null
              : Border.all(color: const Color(0xFFF3F2F3), width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: primary
                  ? const Color(0x59AD80FF)
                  : const Color(0x33B5B5B5),
              offset: const Offset(0, 16),
              blurRadius: 20,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AppText(
          label,
          style: TextStyle(
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            color: primary ? Colors.white : const Color(0xFF0B081A),
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.ui,
    required this.track,
    required this.lesson,
    required this.onTap,
  });

  final double Function(num) ui;
  final SmartDictationTrack track;
  final SmartDictationLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(12)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(10), ui(10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LessonCover(ui: ui, track: track, unlocked: lesson.unlocked),
              SizedBox(width: ui(8)),
              Expanded(
                child: SizedBox(
                  height: ui(80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: ui(4)),
                      AppText(
                        '第${lesson.number}课',
                        style: TextStyle(
                          fontSize: ui(13),
                          color: const Color(0xFF0B081A),
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w500,
                          height: 12 / 13,
                        ),
                      ),
                      SizedBox(height: ui(8)),
                      AppText(
                        lesson.subtitle.isEmpty ? '标准音上下行二度' : lesson.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(11),
                          color: const Color(0xFFB6B5BB),
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w400,
                          height: 12 / 11,
                        ),
                      ),
                      SizedBox(height: ui(4)),
                      const Spacer(),
                      if (lesson.unlocked)
                        SizedBox(
                          height: ui(28),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List<Widget>.generate(3, (index) {
                                    final filled =
                                        index < lesson.stars.clamp(0, 3);
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: index == 2 ? 0 : ui(4),
                                      ),
                                      child: SizedBox(
                                        width: ui(16),
                                        height: ui(16),
                                        child: Image.asset(
                                          filled
                                              ? AppAssets
                                                    .smartDictationFigmaStarOn
                                              : AppAssets
                                                    .smartDictationFigmaStarOff,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: ui(72),
                                  height: ui(28),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF292151),
                                    borderRadius: BorderRadius.circular(ui(8)),
                                  ),
                                  alignment: Alignment.center,
                                  child: AppText(
                                    '去闯关',
                                    style: TextStyle(
                                      fontSize: ui(11),
                                      color: Colors.white,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: FontWeight.w500,
                                      height: 12 / 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          // Keep the lock hint baseline ~6px above the cover bottom.
                          padding: EdgeInsets.only(bottom: ui(6)),
                          child: SizedBox(
                            width: ui(153),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: ui(12),
                                  height: ui(12),
                                  child: Image.asset(
                                    AppAssets.smartDictationFigmaLock,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(width: ui(4)),
                                Expanded(
                                  child: AppText(
                                    '通过上一课即可解锁',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ui(11),
                                      color: const Color(0xFF0B081A),
                                      fontFamily: 'PingFang SC',
                                      fontWeight: FontWeight.w400,
                                      height: 12 / 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCover extends StatelessWidget {
  const _LessonCover({
    required this.ui,
    required this.track,
    required this.unlocked,
  });

  final double Function(num) ui;
  final SmartDictationTrack track;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final coverText = switch (track) {
      SmartDictationTrack.absolute => '听选\n单音',
      SmartDictationTrack.interval => '听选\n音程',
      SmartDictationTrack.chord => '听选\n和弦',
    };
    final bgStart = unlocked
        ? const Color(0xFFDBCCF9)
        : const Color(0xFFD3D3DC);
    final bgMid = unlocked ? const Color(0xFFE1C6FC) : const Color(0xFFCCCCD6);
    final bgEnd = unlocked ? const Color(0xFFCBBFFF) : const Color(0xFFC2C2CC);
    final textColor = unlocked
        ? const Color(0xFFB16AFF)
        : Colors.white.withValues(alpha: 0.7);
    final strip = unlocked ? const Color(0xFFDAC6FF) : const Color(0xFFC7C6CE);
    final line = unlocked ? const Color(0xFFCBAFFA) : const Color(0xFFB9B8C3);
    final noteColor = unlocked
        ? const Color(0xFFBA91FF)
        : const Color(0xFFB0AABB);

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(60),
        height: ui(80),
        child: Stack(
          children: [
            // gradient background
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[bgStart, bgMid, bgEnd],
                    stops: const <double>[0, 0.48, 1],
                  ),
                ),
              ),
            ),
            // 6px left strip
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: ui(6),
                child: ColoredBox(color: strip),
              ),
            ),
            // 2px gradient line
            Positioned(
              left: ui(4),
              top: 0,
              bottom: 0,
              child: Container(
                width: ui(2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[line, line.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            // 1px white highlight
            Positioned(
              left: ui(6),
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.5,
                child: Container(
                  width: ui(1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white,
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // cover text
            Positioned(
              left: ui(18),
              top: ui(10),
              child: AppText(
                coverText,
                style: TextStyle(
                  fontSize: ui(12),
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            // music note overlay
            Positioned(
              left: ui(23),
              top: ui(41),
              child: SizedBox(
                width: ui(59),
                height: ui(37),
                child: Image.asset(
                  AppAssets.smartDictationFigmaLessonNote,
                  fit: BoxFit.cover,
                  color: noteColor,
                  colorBlendMode: BlendMode.srcATop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart practice widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Parses a raw note string (e.g. '#g2', 'be1', 'bb') into a [TextSpan] where
/// sharp/flat prefixes and octave-number suffixes are rendered at ~64% font size.
TextSpan _buildNoteSpan(String note, TextStyle base) {
  final small = base.copyWith(fontSize: (base.fontSize ?? 14.0) * 0.64);
  final spans = <InlineSpan>[];
  String s = note;

  // sharp prefix
  if (s.startsWith('#')) {
    spans.add(TextSpan(text: '#', style: small));
    s = s.substring(1);
  } else if (s.length > 1 &&
      s[0] == 'b' &&
      s[1].compareTo('a') >= 0 &&
      s[1].compareTo('z') <= 0) {
    // flat prefix: 'b' followed by a letter (e.g. 'bb', 'be1')
    spans.add(TextSpan(text: 'b', style: small));
    s = s.substring(1);
  }

  // octave suffix
  if (s.isNotEmpty && (s.endsWith('1') || s.endsWith('2'))) {
    spans.add(TextSpan(text: s.substring(0, s.length - 1), style: base));
    spans.add(TextSpan(text: s.substring(s.length - 1), style: small));
  } else {
    spans.add(TextSpan(text: s, style: base));
  }

  return TextSpan(children: spans);
}

class _NoteNameText extends StatelessWidget {
  const _NoteNameText({
    required this.ui,
    required this.note,
    required this.style,
  });

  final double Function(num) ui;
  final String note;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    var s = note.trim();
    String? prefix;
    String? suffix;

    if (s.startsWith('#')) {
      prefix = '#';
      s = s.substring(1);
    } else if (s.length > 1 &&
        s[0] == 'b' &&
        s[1].compareTo('a') >= 0 &&
        s[1].compareTo('z') <= 0) {
      prefix = 'b';
      s = s.substring(1);
    }

    if (s.isNotEmpty && RegExp(r'\d$').hasMatch(s)) {
      suffix = s.substring(s.length - 1);
      s = s.substring(0, s.length - 1);
    }

    return SizedBox(
      width: ui(31),
      height: ui(28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.center,
            child: AppText(s, style: style, textAlign: TextAlign.center),
          ),
          if (prefix != null)
            Positioned(
              left: 0,
              top: ui(-2),
              child: AppText(prefix, style: style, textAlign: TextAlign.center),
            ),
          if (suffix != null)
            Positioned(
              right: 0,
              top: ui(-2),
              child: AppText(suffix, style: style, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

/// Large option chip used in the top selection grid of the smart practice view.
/// Note chips are 52×52 (absolute track); interval/chord chips are 98×56.
class _SmartOptionChip extends StatelessWidget {
  const _SmartOptionChip({
    required this.ui,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isNoteChip = false,
    this.enabled = true,
  });

  final double Function(num) ui;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isNoteChip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final w = isNoteChip ? ui(52) : ui(98);
    final h = isNoteChip ? ui(52) : ui(56);
    final textColor = selected ? Colors.white : const Color(0xFF0B081A);
    final textStyle = TextStyle(
      fontSize: ui(16),
      fontFamily: 'PingFang SC',
      fontWeight: FontWeight.w600,
      color: textColor,
      height: 28 / 16,
    );
    final hasChinese = label.contains(RegExp(r'[\u4e00-\u9fff/]'));

    final child = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFEFF3FC), width: ui(1)),
      ),
      padding: EdgeInsets.all(ui(0.5)),
      child: Container(
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF6D6B75), Color(0xFF0B081A)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFF5F6FA), Color(0xFFEDEFF5)],
                ),
          borderRadius: BorderRadius.circular(ui(7.5)),
          border: Border.all(color: Colors.white, width: ui(0.5)),
        ),
        alignment: Alignment.center,
        child: hasChinese
            ? AppText(label, style: textStyle, textAlign: TextAlign.center)
            : isNoteChip
            ? _NoteNameText(ui: ui, note: label, style: textStyle)
            : Text.rich(_buildNoteSpan(label, textStyle)),
      ),
    );

    return IgnorePointer(
      ignoring: !enabled,
      child: GestureDetector(onTap: enabled ? onTap : null, child: child),
    );
  }
}

/// Small horizontal chip used for time, count, range, and mode rows.
/// NOTE: must NOT use Container.alignment – that forces full-width expansion
/// inside a Wrap. Use symmetric vertical padding + height:1.0 on TextStyle instead.
class _SmartRowChip extends StatelessWidget {
  const _SmartRowChip({
    required this.ui,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isNote = false,
  });

  final double Function(num) ui;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isNote;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : const Color(0xFF0B081A);
    final textStyle = TextStyle(
      fontSize: ui(14),
      fontFamily: 'PingFang SC',
      fontWeight: FontWeight.w400,
      color: textColor,
      height: 1.0,
    );

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0B081A) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(9)),
          child: isNote
              ? Text.rich(_buildNoteSpan(label, textStyle))
              : AppText(label, style: textStyle),
        ),
      ),
    );
  }
}

/// A setting section: title + Wrap of chips, or title + toggle row.
class _SmartSettingRow extends StatelessWidget {
  const _SmartSettingRow({
    required this.ui,
    required this.title,
    this.children = const <Widget>[],
    this.toggleValue,
    this.onToggle,
  });

  final double Function(num) ui;
  final String title;
  final List<Widget> children;
  final bool? toggleValue;
  final void Function(bool)? onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: TextStyle(
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            color: Colors.black,
            height: 28 / 16,
          ),
        ),
        SizedBox(height: ui(12)),
        if (toggleValue != null)
          _SmartToggleRow(
            ui: ui,
            value: toggleValue!,
            onChanged: onToggle ?? (_) {},
          )
        else
          Wrap(spacing: ui(12), runSpacing: ui(8), children: children),
      ],
    );
  }
}

/// Black-pill iOS-style toggle + 开/关 label.
class _SmartToggleRow extends StatelessWidget {
  const _SmartToggleRow({
    required this.ui,
    required this.value,
    required this.onChanged,
  });

  final double Function(num) ui;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: ui(44),
            height: ui(24),
            padding: EdgeInsets.all(ui(2)),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF0B081A) : const Color(0xFFD1D1D1),
              borderRadius: BorderRadius.circular(ui(9999)),
            ),
            child: Container(
              width: ui(20),
              height: ui(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(9999)),
              ),
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        AppText(
          value ? '开' : '关',
          style: TextStyle(
            fontSize: ui(13),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB6B5BB),
            height: 20 / 13,
          ),
        ),
      ],
    );
  }
}
