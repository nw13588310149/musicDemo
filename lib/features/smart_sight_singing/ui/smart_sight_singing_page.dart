import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/ui/shell_layout.dart';
import '../audio/midi_sight_singing_service.dart';
import '../audio/pitch_track.dart';
import '../state/smart_sight_singing_controller.dart';
import '../state/smart_sight_singing_state.dart';
import 'widgets/karaoke_pitch_track.dart';

/// 智能视唱主页：内置 demo.mid → MIDI 参考轨 → 跟唱实时打分。
class SmartSightSingingPage extends ConsumerStatefulWidget {
  const SmartSightSingingPage({super.key});

  @override
  ConsumerState<SmartSightSingingPage> createState() =>
      _SmartSightSingingPageState();
}

class _SmartSightSingingPageState
    extends ConsumerState<SmartSightSingingPage> {
  final TextEditingController _onlineUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(smartSightSingingControllerProvider.notifier).reportError(
          'Web 端暂不支持智能视唱实时录音，请在 iPad 上使用。',
        );
      });
    }
  }

  @override
  void dispose() {
    _onlineUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartSightSingingControllerProvider);
    final controller = ref.read(
      smartSightSingingControllerProvider.notifier,
    );

    final ui = DashboardScaleScope.of(context).ui;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  state: state,
                  onImport: () => controller.importAudio(),
                ),
                if (state.errorMessage != null) ...[
                  SizedBox(height: ui(12)),
                  if (kDebugMode)
                    _DebugErrorPanel(
                      message: state.errorMessage!,
                      stage: state.stage,
                      onDismiss: controller.dismissError,
                    )
                  else
                    _UserErrorBanner(
                      message: state.errorMessage!.split('\n').first,
                      onDismiss: controller.dismissError,
                    ),
                ],
                SizedBox(height: ui(16)),
                Expanded(
                  child: _Body(
                    state: state,
                    controller: controller,
                    onlineUrlController: _onlineUrlController,
                  ),
                ),
              ],
            ),
          ),
          const Positioned.fill(child: _TrialWatermark()),
        ],
      ),
    );
  }
}

/// 正式环境：单行错误提示（不含 stack）。
class _UserErrorBanner extends StatelessWidget {
  const _UserErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: ui(18)),
          SizedBox(width: ui(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFB71C1C),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            child: Padding(
              padding: EdgeInsets.all(ui(4)),
              child: Icon(Icons.close, size: ui(18), color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 调试阶段：在页面上直接展示完整错误（含 stack），便于排查解码/权限等问题。
class _DebugErrorPanel extends StatelessWidget {
  const _DebugErrorPanel({
    required this.message,
    required this.stage,
    required this.onDismiss,
  });

  final String message;
  final SightSingingStage stage;
  final VoidCallback onDismiss;

  static String _stageLabel(SightSingingStage stage) {
    return switch (stage) {
      SightSingingStage.idle => 'idle',
      SightSingingStage.analyzing => 'analyzing',
      SightSingingStage.selectTrack => 'selectTrack',
      SightSingingStage.ready => 'ready',
      SightSingingStage.countdown => 'countdown',
      SightSingingStage.singing => 'singing',
      SightSingingStage.finished => 'finished',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(180),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report_outlined, color: Colors.red.shade700, size: ui(18)),
              SizedBox(width: ui(6)),
              Text(
                '调试错误（stage: ${_stageLabel(stage)}）',
                style: TextStyle(
                  fontSize: ui(13),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB71C1C),
                  fontFamily: 'PingFang SC',
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(8),
                    vertical: ui(4),
                  ),
                  child: Text(
                    '关闭',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFFB71C1C),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                message,
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.45,
                  color: const Color(0xFF4A1515),
                  fontFamily: 'Consolas',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialWatermark extends StatelessWidget {
  const _TrialWatermark();

  static const String _text = 'loti\u63d2\u4ef6-\u8bd5\u7528\u7248';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = ui(210);
            final tileHeight = ui(112);
            final columns = (constraints.maxWidth / tileWidth).ceil() + 1;
            final rows = (constraints.maxHeight / tileHeight).ceil() + 1;
            final textStyle = TextStyle(
              fontSize: ui(20),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0B081A),
              letterSpacing: ui(0.8),
              fontFamily: 'PingFang SC',
            );

            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var row = 0; row < rows; row++)
                    for (var col = 0; col < columns; col++)
                      Positioned(
                        left: col * tileWidth,
                        top: row * tileHeight,
                        width: tileWidth,
                        height: tileHeight,
                        child: Opacity(
                          opacity: 0.13,
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.52,
                              child: Text(
                                _text,
                                textAlign: TextAlign.center,
                                style: textStyle,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onImport});
  final SightSingingState state;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(40),
          height: ui(40),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8741FF), Color(0xFF3B82F6)],
            ),
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 22),
        ),
        SizedBox(width: ui(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '智能视唱',
              style: TextStyle(
                fontSize: ui(20),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
              ),
            ),
            SizedBox(height: ui(2)),
            Text(
              _subtitle(state),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFF788698),
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
        const Spacer(),
        if (state.stage != SightSingingStage.singing &&
            state.stage != SightSingingStage.countdown)
          _ActionButton(
            label: _importLabel(state),
            icon: Icons.auto_graph_rounded,
            primary: !state.hasTrack && !state.isSelectingTrack,
            onTap: state.isBusy ? null : onImport,
          ),
      ],
    );
  }

  String _subtitle(SightSingingState state) {
    if (state.audioName == null) {
      return '内置 demo → 选轨 → KTV 跟唱 → 实时打分';
    }
    if (state.melodyTrackIndex != null) {
      return '${state.audioName} · 主旋律轨 ${state.melodyTrackIndex}';
    }
    return state.audioName!;
  }

  String _importLabel(SightSingingState state) {
    if (state.isSelectingTrack) return '重新解析';
    if (state.hasTrack) return '重新解析';
    return '解析 demo';
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.controller,
    required this.onlineUrlController,
  });
  final SightSingingState state;
  final SmartSightSingingController controller;
  final TextEditingController onlineUrlController;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    switch (state.stage) {
      case SightSingingStage.idle:
        return _EmptyHint(
          onImport: controller.importAudio,
          onlineUrlController: onlineUrlController,
          onAnalyzeUrl: controller.analyzeOnlineAudio,
        );
      case SightSingingStage.analyzing:
        return _AnalyzingHint(state: state);
      case SightSingingStage.selectTrack:
        return _TrackSelectionPanel(
          state: state,
          controller: controller,
        );
      case SightSingingStage.countdown:
        final track = state.track;
        if (track == null || track.isEmpty) {
          return _EmptyHint(
            onImport: controller.importAudio,
            onlineUrlController: onlineUrlController,
            onAnalyzeUrl: controller.analyzeOnlineAudio,
          );
        }
        return Stack(
          children: [
            Column(
              children: [
                _ScoreBoard(state: state),
                SizedBox(height: ui(12)),
                Expanded(
                  child: KaraokePitchTrack(
                    track: track,
                    playbackMs: 0,
                    userPoints: const <UserPitchPoint>[],
                    currentUserMidi: state.currentUserMidi,
                  ),
                ),
                SizedBox(height: ui(12)),
                _Controls(state: state, controller: controller),
              ],
            ),
            _CountdownOverlay(seconds: state.countdownSeconds),
          ],
        );
      case SightSingingStage.ready:
      case SightSingingStage.singing:
      case SightSingingStage.finished:
        final track = state.track;
        if (track == null || track.isEmpty) {
          return _EmptyHint(
            onImport: controller.importAudio,
            onlineUrlController: onlineUrlController,
            onAnalyzeUrl: controller.analyzeOnlineAudio,
          );
        }
        return Column(
          children: [
            _ScoreBoard(state: state),
            SizedBox(height: ui(12)),
            Expanded(
              child: KaraokePitchTrack(
                track: track,
                playbackMs: state.playbackMs,
                userPoints: state.userPoints,
                currentUserMidi: state.currentUserMidi,
              ),
            ),
            SizedBox(height: ui(12)),
            _Controls(state: state, controller: controller),
          ],
        );
    }
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.onImport,
    required this.onlineUrlController,
    required this.onAnalyzeUrl,
  });
  final VoidCallback onImport;
  final TextEditingController onlineUrlController;
  final ValueChanged<String> onAnalyzeUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(96),
            height: ui(96),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEAE2FF), Color(0xFFDDE9FF)],
              ),
            ),
            child: const Icon(
              Icons.library_music_rounded,
              size: 48,
              color: Color(0xFF8741FF),
            ),
          ),
          SizedBox(height: ui(20)),
          Text(
            '解析 demo，开启智能视唱',
            style: TextStyle(
              fontSize: ui(18),
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          SizedBox(
            width: ui(360),
            child: Text(
              '使用内置 demo.mid 作为示例曲目。解析后请选择一条主旋律轨，'
              '确认后生成参考音符条，随后跟唱并实时看到偏差与得分。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF788698),
                fontFamily: 'PingFang SC',
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: ui(24)),
          _ActionButton(
            label: '解析 demo',
            icon: Icons.auto_graph_rounded,
            primary: true,
            onTap: onImport,
          ),
          SizedBox(height: ui(18)),
          SizedBox(
            width: ui(520),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: onlineUrlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: onAnalyzeUrl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入在线 MIDI 地址（.mid / .midi）',
                      prefixIcon: const Icon(Icons.link_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ui(12)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ui(12),
                        vertical: ui(12),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ui(13),
                      color: const Color(0xFF1A1A1A),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
                SizedBox(width: ui(10)),
                _ActionButton(
                  label: '解析链接',
                  icon: Icons.cloud_download_outlined,
                  primary: false,
                  onTap: () => onAnalyzeUrl(onlineUrlController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingHint extends StatelessWidget {
  const _AnalyzingHint({required this.state});
  final SightSingingState state;
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: ui(64),
            height: ui(64),
            child: const CircularProgressIndicator(
              strokeWidth: 4,
              color: Color(0xFF8741FF),
            ),
          ),
          SizedBox(height: ui(18)),
          Text(
            '正在解析「${state.audioName ?? 'MIDI'}」…',
            style: TextStyle(
              fontSize: ui(15),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            '读取各轨道信息，随后请你选择主旋律轨…',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.state});
  final SightSingingState state;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ref = state.track?.sampleAt(state.playbackMs);
    final refName = ref != null
        ? PitchUtils.midiToNoteName(ref.midi)
        : '--';
    final userName = state.currentUserMidi > 0
        ? PitchUtils.midiToNoteName(state.currentUserMidi)
        : '--';

    final progress = state.track == null || state.track!.totalMs == 0
        ? 0.0
        : (state.playbackMs / state.track!.totalMs).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF6F1FF), Color(0xFFEEF4FF)],
        ),
        borderRadius: BorderRadius.circular(ui(14)),
      ),
      child: Row(
        children: [
          _ScoreCell(label: '得分', value: '${state.currentScore}'),
          SizedBox(width: ui(24)),
          _ScoreCell(label: '连击', value: '${state.combo}'),
          SizedBox(width: ui(24)),
          _ScoreCell(
            label: '命中率',
            value: state.scoredCount == 0
                ? '--'
                : '${(100 * state.hitCount / state.scoredCount).round()}%',
          ),
          SizedBox(width: ui(24)),
          _ScoreCell(label: '标准音', value: refName),
          SizedBox(width: ui(24)),
          _ScoreCell(label: '你的音', value: userName),
          const Spacer(),
          // 进度条。
          SizedBox(
            width: ui(180),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(4)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: ui(6),
                backgroundColor: const Color(0x33000000),
                color: const Color(0xFF8741FF),
              ),
            ),
          ),
          SizedBox(width: ui(10)),
          Text(
            _formatMs(state.playbackMs),
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF1A1A1A),
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(11),
            color: const Color(0xFF788698),
            fontFamily: 'PingFang SC',
          ),
        ),
        SizedBox(height: ui(2)),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(20),
            color: const Color(0xFF1A1A1A),
            fontFamily: 'Barlow',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrackSelectionPanel extends StatelessWidget {
  const _TrackSelectionPanel({
    required this.state,
    required this.controller,
  });

  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selected = state.selectedTrackIndex;

    MidiTrackSummary? findSummary(int trackIndex) {
      for (final s in state.trackSummaries) {
        if (s.trackIndex == trackIndex) return s;
      }
      return null;
    }

    final summary = selected == null ? null : findSummary(selected);
    final canConfirm = summary?.hasNotes ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '选择主旋律轨',
          style: TextStyle(
            fontSize: ui(18),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
            fontFamily: 'PingFang SC',
          ),
        ),
        SizedBox(height: ui(6)),
        Text(
          '「${state.audioName ?? 'MIDI'}」共 ${state.trackSummaries.length} 条轨道。'
          '系统已预选推荐轨，请确认或改选后再开始跟唱。',
          style: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFF788698),
            fontFamily: 'PingFang SC',
            height: 1.45,
          ),
        ),
        SizedBox(height: ui(14)),
        Expanded(
          child: ListView.separated(
            itemCount: state.trackSummaries.length,
            separatorBuilder: (_, _) => SizedBox(height: ui(8)),
            itemBuilder: (context, index) {
              final item = state.trackSummaries[index];
              final isSelected = item.trackIndex == selected;
              return _TrackListTile(
                summary: item,
                selected: isSelected,
                onTap: item.hasNotes
                    ? () => controller.setSelectedTrack(item.trackIndex)
                    : null,
              );
            },
          ),
        ),
        SizedBox(height: ui(12)),
        Row(
          children: [
            Text(
              summary == null
                  ? '请选择一条含音符的轨道'
                  : summary.hasNotes
                      ? '已选轨 ${summary.trackIndex} · ${summary.noteCount} 个音符 · ${summary.pitchRangeLabel}'
                      : '轨 ${summary.trackIndex} 无音符，请换选',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
              ),
            ),
            const Spacer(),
            _ActionButton(
              label: '取消',
              icon: Icons.close_rounded,
              primary: false,
              onTap: controller.cancelTrackSelection,
            ),
            SizedBox(width: ui(10)),
            _ActionButton(
              label: '确认轨道',
              icon: Icons.check_rounded,
              primary: true,
              onTap: canConfirm ? controller.confirmSelectedTrack : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _TrackListTile extends StatelessWidget {
  const _TrackListTile({
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final MidiTrackSummary summary;
  final bool selected;
  final VoidCallback? onTap;

  String _formatDuration(int ms) {
    final s = ms ~/ 1000;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = !summary.hasNotes;
    final borderColor = selected
        ? const Color(0xFF8741FF)
        : const Color(0xFFE5E7EF);
    final bg = selected
        ? const Color(0xFFF6F1FF)
        : disabled
            ? const Color(0xFFFAFAFC)
            : Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: disabled
                    ? const Color(0xFFB0B6C2)
                    : selected
                        ? const Color(0xFF8741FF)
                        : const Color(0xFF788698),
                size: ui(20),
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '轨道 ${summary.trackIndex}',
                          style: TextStyle(
                            fontSize: ui(14),
                            fontWeight: FontWeight.w600,
                            color: disabled
                                ? const Color(0xFFB0B6C2)
                                : const Color(0xFF1A1A1A),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        if (summary.recommended) ...[
                          SizedBox(width: ui(8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ui(8),
                              vertical: ui(2),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(ui(8)),
                            ),
                            child: Text(
                              '推荐',
                              style: TextStyle(
                                fontSize: ui(11),
                                color: const Color(0xFF2E7D32),
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      summary.hasNotes
                          ? '${summary.noteCount} 个音符 · ${summary.pitchRangeLabel} · ${_formatDuration(summary.durationMs)}'
                          : '无音符',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF788698),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: TextStyle(
                  fontSize: ui(96),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Barlow',
                  height: 1,
                ),
              ),
              SizedBox(height: ui(12)),
              Text(
                '准备跟唱…',
                style: TextStyle(
                  fontSize: ui(18),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});
  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final singing = state.stage == SightSingingStage.singing;
    final countdown = state.stage == SightSingingStage.countdown;
    return Row(
      children: [
        Text(
          countdown
              ? '倒计时中，请准备…'
              : state.stage == SightSingingStage.finished
                  ? '本次演唱结束 · 综合得分 ${state.currentScore}'
                  : singing
                      ? '正在跟唱中…保持音准更稳更高分'
                      : '准备就绪，点击「开始跟唱」即可',
          style: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFF1A1A1A),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (countdown)
          _ActionButton(
            label: '取消',
            icon: Icons.close_rounded,
            primary: false,
            onTap: () => controller.cancelCountdown(),
          )
        else if (singing)
          _ActionButton(
            label: '停止',
            icon: Icons.stop_rounded,
            primary: false,
            onTap: () => controller.stopSinging(),
          )
        else
          _ActionButton(
            label: state.stage == SightSingingStage.finished
                ? '重新跟唱'
                : '开始跟唱',
            icon: Icons.mic_rounded,
            primary: true,
            onTap: () => controller.startSinging(),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    final bg = disabled
        ? const Color(0xFFE5E5EF)
        : primary
            ? const Color(0xFF8741FF)
            : Colors.white;
    final fg = disabled
        ? const Color(0xFFB0B6C2)
        : primary
            ? Colors.white
            : const Color(0xFF8741FF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(24)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(18), vertical: ui(10)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(24)),
          border: primary || disabled
              ? null
              : Border.all(color: const Color(0xFF8741FF), width: 1),
          boxShadow: primary && !disabled
              ? const [
                  BoxShadow(
                    color: Color(0x408741FF),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: ui(18)),
            SizedBox(width: ui(6)),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: ui(14),
                fontWeight: FontWeight.w600,
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
