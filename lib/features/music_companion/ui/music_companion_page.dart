import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../piano/ui/piano_keyboard.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/music_companion_controller.dart';
import '../state/music_companion_state.dart';
import 'widgets/piano_visualizer.dart';

class MusicCompanionV2Page extends ConsumerStatefulWidget {
  const MusicCompanionV2Page({super.key});

  @override
  ConsumerState<MusicCompanionV2Page> createState() =>
      _MusicCompanionV2PageState();
}

class _MusicCompanionV2PageState extends ConsumerState<MusicCompanionV2Page> {
  @override
  Widget build(BuildContext context) {
    ref.listen<MusicCompanionState>(musicCompanionControllerProvider, (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message == null || message == previous?.errorMessage || !mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(musicCompanionControllerProvider.notifier).clearError();
    });

    final state = ref.watch(musicCompanionControllerProvider);
    final controller = ref.read(musicCompanionControllerProvider.notifier);
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompanionTabBar(
            activeTab: state.activeTab,
            onTabSelected: controller.setTab,
          ),
          SizedBox(height: ui(18)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (state.activeTab) {
                MusicCompanionTab.piano => _VirtualPianoPane(
                  key: const ValueKey<String>('music_piano'),
                  activeNotes: state.activePianoNotes,
                  onPressKey: controller.pressPianoKey,
                  onReleaseKey: controller.releasePianoKey,
                ),
                MusicCompanionTab.metronome => _MetronomePane(
                  key: const ValueKey<String>('music_metronome'),
                  state: state,
                  onToneSelected: controller.setMetronomeTone,
                  onSignatureSelected: controller.setMetronomeSignature,
                  onToggle: controller.toggleMetronome,
                  onBpmChanged: controller.setMetronomeBpm,
                  onDecreaseBpm: () => controller.nudgeMetronomeBpm(-1),
                  onIncreaseBpm: () => controller.nudgeMetronomeBpm(1),
                ),
                MusicCompanionTab.tuner => _TunerPane(
                  key: const ValueKey<String>('music_tuner'),
                  state: state,
                  onDecreaseFrequency: () =>
                      controller.nudgeTunerReferenceFrequency(-1),
                  onIncreaseFrequency: () =>
                      controller.nudgeTunerReferenceFrequency(1),
                  onUse442Hz: () => controller.setTunerReferenceFrequency(442),
                  onRetryPermission: controller.retryTunerPermission,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionTabBar extends StatelessWidget {
  const _CompanionTabBar({
    required this.activeTab,
    required this.onTabSelected,
  });

  final MusicCompanionTab activeTab;
  final ValueChanged<MusicCompanionTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final tabs = MusicCompanionTab.values;
    return Container(
      // 高度 44，padding 4/4/3/4（左/上/右/下）按 Figma；
      // 不再设固定 width，改由内容自适应，避免不同字体/dpr 下被裁。
      height: ui(44),
      padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < tabs.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: ui(16)),
            _CompanionTabItem(
              tab: tabs[i],
              active: activeTab == tabs[i],
              onTap: () => onTabSelected(tabs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanionTabItem extends StatelessWidget {
  const _CompanionTabItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final MusicCompanionTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final label = switch (tab) {
      MusicCompanionTab.piano => '虚拟钢琴',
      MusicCompanionTab.metronome => '节拍器',
      MusicCompanionTab.tuner => '调音器',
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          // Figma: active 6px、inactive 8px
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x59B5B5B5),
                    blurRadius: ui(20),
                    offset: Offset(0, ui(8)),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            height: 1,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            color: active
                ? const Color(0xFF0B081A)
                : const Color(0xFF6D6B75),
          ),
        ),
      ),
    );
  }
}

class _VirtualPianoPane extends StatelessWidget {
  const _VirtualPianoPane({
    required this.activeNotes,
    required this.onPressKey,
    required this.onReleaseKey,
    super.key,
  });

  final Set<String> activeNotes;
  final Future<void> Function(String token) onPressKey;
  final ValueChanged<String> onReleaseKey;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(24)),
            child: RepaintBoundary(
              child: PianoVisualizer(activeNotes: activeNotes),
            ),
          ),
        ),
        SizedBox(height: ui(18)),
        RepaintBoundary(
          child: PianoKeyboard(
            activeNotes: activeNotes,
            onPress: onPressKey,
            onRelease: onReleaseKey,
            height: 240,
          ),
        ),
      ],
    );
  }
}

class _MetronomePane extends StatelessWidget {
  const _MetronomePane({
    required this.state,
    required this.onToneSelected,
    required this.onSignatureSelected,
    required this.onToggle,
    required this.onBpmChanged,
    required this.onDecreaseBpm,
    required this.onIncreaseBpm,
    super.key,
  });

  final MusicCompanionState state;
  final ValueChanged<int> onToneSelected;
  final ValueChanged<int> onSignatureSelected;
  final Future<void> Function() onToggle;
  final ValueChanged<double> onBpmChanged;
  final VoidCallback onDecreaseBpm;
  final VoidCallback onIncreaseBpm;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetronomeHeaderCard(state: state, onToggle: onToggle),
          SizedBox(height: ui(18)),
          Text(
            '音色选择',
            style: TextStyle(
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: ui(12)),
          Row(
            children: [
              for (var i = 0; i < kMusicCompanionToneOptions.length; i++) ...[
                _ChoiceChipButton(
                  label: kMusicCompanionToneOptions[i].label,
                  selected: i == state.metronomeToneIndex,
                  width: ui(92),
                  onTap: () => onToneSelected(i),
                ),
                if (i != kMusicCompanionToneOptions.length - 1)
                  SizedBox(width: ui(24)),
              ],
            ],
          ),
          SizedBox(height: ui(18)),
          Text(
            '节拍选择',
            style: TextStyle(
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: ui(12)),
          Wrap(
            spacing: ui(18),
            runSpacing: ui(14),
            children: [
              for (var i = 0; i < kMusicCompanionSignatures.length; i++)
                _ChoiceChipButton(
                  label: kMusicCompanionSignatures[i].label,
                  selected: i == state.metronomeSignatureIndex,
                  width: ui(90),
                  onTap: () => onSignatureSelected(i),
                ),
            ],
          ),
          const Spacer(),
          _MetronomeTempoSlider(
            bpm: state.metronomeBpm,
            playing: state.metronomePlaying,
            onChanged: onBpmChanged,
            onDecrease: onDecreaseBpm,
            onIncrease: onIncreaseBpm,
            onToggle: onToggle,
          ),
        ],
      ),
    );
  }
}

class _MetronomeHeaderCard extends StatelessWidget {
  const _MetronomeHeaderCard({required this.state, required this.onToggle});

  final MusicCompanionState state;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final beatCount = state.activeSignature.visualBeatCount;
    final activeDot = state.metronomePlaying && state.metronomeActiveBeat >= 0
        ? state.metronomeActiveBeat % beatCount
        : -1;

    return Container(
      width: double.infinity,
      height: ui(124),
      padding: EdgeInsets.symmetric(horizontal: ui(32)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FD),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ui(186),
            height: ui(88),
            child: CustomPaint(
              painter: _MetronomeGaugePainter(
                progress: (state.metronomeBpm - 15) / 285,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              for (var i = 0; i < beatCount; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: ui(20),
                  height: ui(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == activeDot
                        ? const Color(0xFF7F46FF)
                        : const Color(0xFFE2E6F2),
                  ),
                ),
                if (i != beatCount - 1) SizedBox(width: ui(16)),
              ],
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: ui(62),
              height: ui(62),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF9656FF), Color(0xFF7B3FFF)],
                ),
              ),
              child: Icon(
                state.metronomePlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: ui(34),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: ui(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF141228) : const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(ui(8)),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x19141228),
                    blurRadius: ui(8),
                    offset: Offset(0, ui(3)),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF434A59),
          ),
        ),
      ),
    );
  }
}

class _MetronomeTempoSlider extends StatelessWidget {
  const _MetronomeTempoSlider({
    required this.bpm,
    required this.playing,
    required this.onChanged,
    required this.onDecrease,
    required this.onIncrease,
    required this.onToggle,
  });

  final int bpm;
  final bool playing;
  final ValueChanged<double> onChanged;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return Container(
      height: ui(86),
      padding: EdgeInsets.symmetric(horizontal: ui(18)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEFF),
        borderRadius: BorderRadius.circular(ui(14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackLeft = ui(46);
          final trackRight = ui(46);
          final trackWidth = constraints.maxWidth - trackLeft - trackRight;
          final fraction = ((bpm - 15) / 285).clamp(0.0, 1.0);
          final knobX = trackLeft + trackWidth * fraction;

          void updatePosition(Offset localPosition) {
            final normalized = ((localPosition.dx - trackLeft) / trackWidth)
                .clamp(0.0, 1.0);
            onChanged(15 + normalized * 285);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => updatePosition(details.localPosition),
            onPanUpdate: (details) => updatePosition(details.localPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: ui(12),
                  left: knobX - ui(30),
                  child: Container(
                    width: ui(60),
                    height: ui(28),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0x16000000),
                          blurRadius: ui(8),
                          offset: Offset(0, ui(3)),
                        ),
                      ],
                    ),
                    child: Text(
                      '速度: $bpm',
                      style: TextStyle(
                        fontSize: ui(12),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: ui(22),
                  child: _CircleActionButton(
                    icon: Icons.remove_rounded,
                    onTap: onDecrease,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: ui(22),
                  child: _CircleActionButton(
                    icon: Icons.add_rounded,
                    onTap: onIncrease,
                  ),
                ),
                Positioned(
                  left: trackLeft,
                  right: trackRight,
                  top: ui(40),
                  child: Container(
                    height: ui(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(999)),
                    ),
                  ),
                ),
                Positioned(
                  left: trackLeft,
                  top: ui(40),
                  child: Container(
                    width: math.max(trackWidth * fraction, ui(8)),
                    height: ui(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F46FF),
                      borderRadius: BorderRadius.circular(ui(999)),
                    ),
                  ),
                ),
                Positioned(
                  left: knobX - ui(14),
                  top: ui(30),
                  child: GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: ui(28),
                      height: ui(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F46FF),
                        borderRadius: BorderRadius.circular(ui(9)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0x337F46FF),
                            blurRadius: ui(12),
                            offset: Offset(0, ui(4)),
                          ),
                        ],
                      ),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: ui(16),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(28),
        height: ui(28),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(icon, size: ui(18), color: const Color(0xFF6C7080)),
      ),
    );
  }
}

class _TunerPane extends StatelessWidget {
  const _TunerPane({
    required this.state,
    required this.onDecreaseFrequency,
    required this.onIncreaseFrequency,
    required this.onUse442Hz,
    required this.onRetryPermission,
    super.key,
  });

  final MusicCompanionState state;
  final VoidCallback onDecreaseFrequency;
  final VoidCallback onIncreaseFrequency;
  final VoidCallback onUse442Hz;
  final Future<void> Function() onRetryPermission;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), ui(18)),
      child: Column(
        children: [
          SizedBox(height: ui(58)),
          Center(
            child: Container(
              width: ui(240),
              height: ui(140),
              padding: EdgeInsets.all(ui(12)),
              decoration: BoxDecoration(
                color: const Color(0xCCE8E9F1),
                borderRadius: BorderRadius.circular(ui(20)),
                border: Border.all(color: Colors.white, width: ui(0.4)),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(12)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF25064A), Color(0xFF090611)],
                  ),
                ),
                child: Center(
                  child: Text(
                    state.tunerNote,
                    style: TextStyle(
                      fontSize: ui(38),
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: ui(26)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleActionButton(
                icon: Icons.remove_rounded,
                onTap: onDecreaseFrequency,
              ),
              SizedBox(width: ui(22)),
              Text(
                '${state.tunerReferenceFrequency}hz',
                style: TextStyle(
                  fontSize: ui(20),
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF151515),
                ),
              ),
              SizedBox(width: ui(22)),
              _CircleActionButton(
                icon: Icons.add_rounded,
                onTap: onIncreaseFrequency,
              ),
            ],
          ),
          SizedBox(height: ui(20)),
          Row(
            children: [
              SizedBox(width: ui(98)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '特定频段',
                    style: TextStyle(
                      fontSize: ui(15),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: ui(12)),
                  GestureDetector(
                    onTap: onUse442Hz,
                    child: Container(
                      width: ui(86),
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: state.tunerReferenceFrequency == 442
                            ? const Color(0xFF141228)
                            : const Color(0xFFF4F5FA),
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Text(
                        '442hz',
                        style: TextStyle(
                          fontSize: ui(13),
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w600,
                          color: state.tunerReferenceFrequency == 442
                              ? Colors.white
                              : const Color(0xFF434A59),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: ui(28)),
          Container(
            width: ui(740),
            height: ui(140),
            padding: EdgeInsets.fromLTRB(ui(24), ui(18), ui(24), ui(18)),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5FD),
              borderRadius: BorderRadius.circular(ui(16)),
            ),
            child: CustomPaint(
              painter: _TunerRulerPainter(cents: state.tunerCents),
            ),
          ),
          SizedBox(height: ui(14)),
          Text(
            state.tunerPermissionGranted
                ? (state.tunerListening
                      ? '实时检测中 ${state.tunerDetectedFrequency.toStringAsFixed(1)}Hz'
                      : '准备开始实时检测')
                : '麦克风未授权，点击这里重新开启',
            style: TextStyle(
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7B8191),
            ),
          ),
          if (!state.tunerPermissionGranted) ...[
            SizedBox(height: ui(10)),
            TextButton(
              onPressed: onRetryPermission,
              child: Text(
                '重新授权麦克风',
                style: TextStyle(
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7F46FF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetronomeGaugePainter extends CustomPainter {
  _MetronomeGaugePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.3, size.height * 1.02);
    final radius = math.min(size.width * 0.44, size.height * 1.05);
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[Color(0xFFE8EAF6), Color(0xFFD8DCF0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[Color(0xFFC48BFF), Color(0xFF7F46FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final startAngle = math.pi;
    final sweepAngle = math.pi * 0.88;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      background,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress.clamp(0.0, 1.0),
      false,
      active,
    );

    final needleAngle = startAngle + sweepAngle * progress.clamp(0.0, 1.0);
    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * radius * 0.8,
      center.dy + math.sin(needleAngle) * radius * 0.8,
    );
    final needlePaint = Paint()
      ..color = const Color(0xFF9B6BFF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF9B6BFF));
  }

  @override
  bool shouldRepaint(covariant _MetronomeGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TunerRulerPainter extends CustomPainter {
  _TunerRulerPainter({required this.cents});

  final double cents;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 18.0;
    final rightPadding = 18.0;
    final contentWidth = size.width - leftPadding - rightPadding;
    final zeroX = leftPadding + contentWidth / 2;
    final tickSpacing = contentWidth / 100;
    final baselineY = size.height * 0.56;

    final basePaint = Paint()
      ..color = const Color(0xFF2F3443)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = const Color(0xFF8F58FF)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final dividerPaint = Paint()
      ..color = const Color(0xFFD7DCEB)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(leftPadding, size.height - 28),
      Offset(size.width - rightPadding, size.height - 28),
      dividerPaint,
    );

    final targetX = zeroX + cents.clamp(-50, 50) * tickSpacing;

    for (var i = -50; i <= 50; i++) {
      final x = zeroX + i * tickSpacing;
      final tickHeight = i % 10 == 0
          ? 30.0
          : i % 5 == 0
          ? 22.0
          : 16.0;
      final isActive = cents >= 0
          ? x >= zeroX && x <= targetX
          : x <= zeroX && x >= targetX;
      canvas.drawLine(
        Offset(x, baselineY - tickHeight),
        Offset(x, baselineY),
        isActive ? activePaint : basePaint,
      );
    }

    _drawMarker(canvas, zeroX, baselineY - 38, const Color(0xFF8F58FF));
    _drawMarker(canvas, targetX, baselineY - 38, const Color(0xFF8F58FF));

    for (var value = -50; value <= 50; value += 10) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$value',
          style: const TextStyle(
            color: Color(0xFF6F7381),
            fontSize: 12,
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = zeroX + value * tickSpacing - textPainter.width / 2;
      textPainter.paint(canvas, Offset(x, size.height - 20));
    }
  }

  void _drawMarker(Canvas canvas, double x, double y, Color color) {
    final path = Path()
      ..moveTo(x, y)
      ..lineTo(x - 4, y - 8)
      ..lineTo(x + 4, y - 8)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TunerRulerPainter oldDelegate) {
    return oldDelegate.cents != cents;
  }
}

