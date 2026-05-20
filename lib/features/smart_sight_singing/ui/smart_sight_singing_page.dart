import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../audio/pitch_track.dart';
import '../state/smart_sight_singing_controller.dart';
import '../state/smart_sight_singing_state.dart';
import 'widgets/karaoke_pitch_track.dart';

/// 智能视唱主页：上传 MP3 → 离线分析音高 → 跟唱实时打分。
class SmartSightSingingPage extends ConsumerStatefulWidget {
  const SmartSightSingingPage({super.key});

  @override
  ConsumerState<SmartSightSingingPage> createState() =>
      _SmartSightSingingPageState();
}

class _SmartSightSingingPageState
    extends ConsumerState<SmartSightSingingPage> {
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppToast.show(
          context,
          'Web 端暂不支持智能视唱实时录音，请在 iPad 上使用。',
          type: AppToastType.error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartSightSingingControllerProvider);
    final controller = ref.read(
      smartSightSingingControllerProvider.notifier,
    );

    if (state.errorMessage != null && state.errorMessage != _lastShownError) {
      _lastShownError = state.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppToast.show(
          context,
          state.errorMessage!,
          type: AppToastType.error,
        );
        controller.dismissError();
      });
    } else if (state.errorMessage == null) {
      _lastShownError = null;
    }

    final ui = DashboardScaleScope.of(context).ui;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              state: state,
              onImport: () => controller.importAudio(),
            ),
            SizedBox(height: ui(16)),
            Expanded(child: _Body(state: state, controller: controller)),
          ],
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
              state.audioName ?? '上传 MP3 → KTV 风格跟唱 → 实时打分',
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
        if (state.stage != SightSingingStage.singing)
          _ActionButton(
            label: state.hasTrack ? '更换音频' : '导入 MP3',
            icon: Icons.upload_file_rounded,
            primary: !state.hasTrack,
            onTap: state.isBusy ? null : onImport,
          ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});
  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    switch (state.stage) {
      case SightSingingStage.idle:
        return _EmptyHint(onImport: controller.importAudio);
      case SightSingingStage.analyzing:
        return _AnalyzingHint(state: state);
      case SightSingingStage.ready:
      case SightSingingStage.singing:
      case SightSingingStage.finished:
        final track = state.track;
        if (track == null || track.isEmpty) {
          return _EmptyHint(onImport: controller.importAudio);
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
  const _EmptyHint({required this.onImport});
  final VoidCallback onImport;

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
            '上传一首歌，开启智能视唱',
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
              '支持 MP3 / M4A / WAV。系统会先离线分析音高曲线，'
              '随后你可以跟唱并实时看到与原曲的偏差与得分。',
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
            label: '导入 MP3',
            icon: Icons.upload_file_rounded,
            primary: true,
            onTap: onImport,
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
            '正在解析「${state.audioName ?? '音频'}」音高…',
            style: TextStyle(
              fontSize: ui(15),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            '解码 → 帧切 → YIN 音高分析（约需 5–15 秒）',
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
    final hitRate = state.scoredCount == 0
        ? 0
        : (100 * state.hitCount / state.scoredCount).round();

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
          _ScoreCell(label: '命中率', value: '$hitRate%'),
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

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});
  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final singing = state.stage == SightSingingStage.singing;
    return Row(
      children: [
        Text(
          state.stage == SightSingingStage.finished
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
        if (singing)
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
