import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../audio/pitch_track.dart';
import '../../config/smart_sight_singing_tuning.dart';
import '../../state/smart_sight_singing_controller.dart';
import '../../state/smart_sight_singing_state.dart';

/// 智能视唱调试面板：实时指标 + 关键参数滑条 + Dart 导出。
///
/// 设计目标：
/// - 在真机调试时即时改参数（音准容差、麦克风延迟、串音阈值、稳定平滑…），
///   全链路实时生效；
/// - 调到满意值后一键导出 Dart 源码片段到剪贴板，直接粘回 config 文件作为新默认；
/// - 不影响生产用户：只有点击页面右上角「调试」按钮才会弹出。
class DebugCalibrationPanel extends ConsumerStatefulWidget {
  const DebugCalibrationPanel({super.key});

  @override
  ConsumerState<DebugCalibrationPanel> createState() =>
      _DebugCalibrationPanelState();
}

class _DebugCalibrationPanelState
    extends ConsumerState<DebugCalibrationPanel> {
  late final VoidCallback _tuningListener;

  @override
  void initState() {
    super.initState();
    _tuningListener = () {
      if (!mounted) return;
      setState(() {});
      ref
          .read(smartSightSingingControllerProvider.notifier)
          .onTuningExternallyChanged();
    };
    SightSingingTuning.instance.addListener(_tuningListener);
  }

  @override
  void dispose() {
    SightSingingTuning.instance.removeListener(_tuningListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartSightSingingControllerProvider);
    final controller = ref.read(smartSightSingingControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;
    final tuning = SightSingingTuning.instance;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: ui(340),
        margin: EdgeInsets.only(left: ui(8)),
        padding: EdgeInsets.fromLTRB(ui(14), ui(12), ui(14), ui(14)),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(ui(16)),
          border: Border.all(color: const Color(0xFFD4DCE7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(-2, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              hasOverride: tuning.hasAnyOverride,
              overrideCount: tuning.overrideCount,
              onClose: () => controller.setDebugPanelVisible(false),
            ),
            SizedBox(height: ui(10)),
            _LiveMetricsCard(state: state),
            SizedBox(height: ui(10)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(title: '评分 / 打分链路', children: [
                      _IntSlider(
                        label: '麦克风延迟补偿',
                        unit: 'ms',
                        value: tuning.micLatencyMs,
                        min: 0,
                        max: 300,
                        divisions: 60,
                        onChanged: (v) => tuning.setMicLatencyMs(v),
                        hint: '系统/外放越慢越要调大；调小避免「评分晚于实唱」',
                      ),
                      _IntSlider(
                        label: '提前演唱窗口',
                        unit: 'ms',
                        value: tuning.earlySingMs,
                        min: 0,
                        max: 300,
                        divisions: 30,
                        onChanged: (v) => tuning.setEarlySingMs(v),
                      ),
                      _IntSlider(
                        label: '延迟离音窗口',
                        unit: 'ms',
                        value: tuning.lateSingMs,
                        min: 0,
                        max: 400,
                        divisions: 40,
                        onChanged: (v) => tuning.setLateSingMs(v),
                      ),
                      _DoubleSlider(
                        label: '命中容差 (Good)',
                        unit: 'cents',
                        value: tuning.defaultStandardCents,
                        min: 30,
                        max: 200,
                        divisions: 34,
                        onChanged: (v) => tuning.setDefaultStandardCents(v),
                        hint: '专业课堂可压到 60~80；公开课/初学 100~120',
                      ),
                      _DoubleSlider(
                        label: 'Perfect 容差',
                        unit: 'cents',
                        value: tuning.perfectCentsAtDefault,
                        min: 15,
                        max: 90,
                        divisions: 15,
                        onChanged: (v) => tuning.setPerfectCentsAtDefault(v),
                      ),
                      _DoubleSlider(
                        label: 'OK 容差',
                        unit: 'cents',
                        value: tuning.okCentsAtDefault,
                        min: 60,
                        max: 240,
                        divisions: 36,
                        onChanged: (v) => tuning.setOkCentsAtDefault(v),
                      ),
                      _BoolRow(
                        label: '严格音域（关闭八度归一）',
                        value: !tuning.octaveNormalizeScoring,
                        onChanged: (v) =>
                            tuning.setOctaveNormalizeScoring(!v),
                        hint: '关闭后唱错八度直接 miss，更适合视唱考试',
                      ),
                    ]),
                    _Section(title: '实时音高 / YIN', children: [
                      _DoubleSlider(
                        label: '最低 RMS',
                        unit: '',
                        value: tuning.realtimeMinRms,
                        min: 40,
                        max: 800,
                        divisions: 76,
                        onChanged: (v) => tuning.setRealtimeMinRms(v),
                        hint: '高=抗噪，低=灵敏；轻声教室建议 80~150',
                      ),
                      _DoubleSlider(
                        label: '帧最低置信度',
                        unit: '',
                        value: tuning.frameMinConfidence,
                        min: 0.15,
                        max: 0.85,
                        divisions: 28,
                        decimals: 2,
                        onChanged: (v) => tuning.setFrameMinConfidence(v),
                      ),
                      _DoubleSlider(
                        label: '自相关最低置信度',
                        unit: '',
                        value: tuning.autocorrelationMinCorrelation,
                        min: 0.15,
                        max: 0.7,
                        divisions: 22,
                        decimals: 2,
                        onChanged: (v) =>
                            tuning.setAutocorrelationMinCorrelation(v),
                      ),
                      _IntSlider(
                        label: '稳定帧数',
                        unit: '帧',
                        value: tuning.stableFrameCount,
                        min: 1,
                        max: 6,
                        divisions: 5,
                        onChanged: (v) => tuning.setStableFrameCount(v),
                        hint: '高=稳但响应慢；通常 2~3',
                      ),
                      _DoubleSlider(
                        label: '稳定相对差',
                        unit: '',
                        value: tuning.stableFrequencyDiffRatio,
                        min: 0.02,
                        max: 0.20,
                        divisions: 18,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setStableFrequencyDiffRatio(v),
                      ),
                      _DoubleSlider(
                        label: '平滑置信度下限',
                        unit: '',
                        value: tuning.smoothedConfidenceFloor,
                        min: 0.3,
                        max: 0.85,
                        divisions: 22,
                        decimals: 2,
                        onChanged: (v) =>
                            tuning.setSmoothedConfidenceFloor(v),
                      ),
                      _IntSlider(
                        label: '静音重置等待',
                        unit: 'ms',
                        value: tuning.silenceResetSmoothingMs,
                        min: 60,
                        max: 600,
                        divisions: 54,
                        onChanged: (v) =>
                            tuning.setSilenceResetSmoothingMs(v),
                        hint: '静音超过该时长后丢弃旧的稳定值（修过的 bug）',
                      ),
                    ]),
                    _Section(title: '人声门控 / 串音过滤', children: [
                      _DoubleSlider(
                        label: '无声跟唱最低响度',
                        unit: '',
                        value: tuning.visualOnlyMinAmplitude,
                        min: 0.002,
                        max: 0.05,
                        divisions: 48,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setVisualOnlyMinAmplitude(v),
                      ),
                      _DoubleSlider(
                        label: '有伴奏最低响度',
                        unit: '',
                        value: tuning.accompanimentMinAmplitude,
                        min: 0.005,
                        max: 0.08,
                        divisions: 75,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setAccompanimentMinAmplitude(v),
                      ),
                      _DoubleSlider(
                        label: '串音最大响度',
                        unit: '',
                        value: tuning.bleedMatchMaxAmplitude,
                        min: 0.02,
                        max: 0.20,
                        divisions: 36,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setBleedMatchMaxAmplitude(v),
                      ),
                      _DoubleSlider(
                        label: '串音音高窗口',
                        unit: 'cents',
                        value: tuning.bleedMatchMaxCents,
                        min: 3,
                        max: 40,
                        divisions: 37,
                        onChanged: (v) => tuning.setBleedMatchMaxCents(v),
                      ),
                      _DoubleSlider(
                        label: '强人声额外响度',
                        unit: '',
                        value: tuning.strongVoiceExtraAmplitude,
                        min: 0.005,
                        max: 0.12,
                        divisions: 23,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setStrongVoiceExtraAmplitude(v),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            SizedBox(height: ui(10)),
            _Actions(
              onReset: tuning.hasAnyOverride
                  ? () async {
                      await tuning.resetAll();
                      if (!context.mounted) return;
                      _showSnack(context, '已恢复默认参数');
                    }
                  : null,
              onExport: () async {
                final code = tuning.exportDartSource();
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                _showSnack(
                  context,
                  tuning.hasAnyOverride
                      ? '已复制 Dart 源码到剪贴板，可粘贴到 smart_sight_singing_config.dart'
                      : '当前没有任何修改可导出',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasOverride,
    required this.overrideCount,
    required this.onClose,
  });

  final bool hasOverride;
  final int overrideCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          color: const Color(0xFF1A1A1A),
          size: ui(20),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '调试面板',
                style: TextStyle(
                  fontSize: ui(14),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(height: ui(2)),
              Text(
                hasOverride
                    ? '已自定义 $overrideCount 项参数（已本地持久化）'
                    : '所有参数为默认值',
                style: TextStyle(
                  fontSize: ui(11),
                  color: const Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(ui(12)),
          child: Padding(
            padding: EdgeInsets.all(ui(4)),
            child: Icon(
              Icons.close_rounded,
              color: const Color(0xFF788698),
              size: ui(20),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveMetricsCard extends StatelessWidget {
  const _LiveMetricsCard({required this.state});

  final SightSingingState state;

  String _midiName(double midi) {
    if (midi < 0 || !midi.isFinite) return '--';
    return PitchUtils.midiToNoteName(midi);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cents = state.lastCents;
    final refMidi = state.lastRefMidi;
    final playbackMidi = state.lastPlaybackMidi;
    final userMidi = state.currentUserMidi;
    final amplitude = state.currentUserAmplitude;

    return Container(
      padding: EdgeInsets.all(ui(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(10)),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Metric(
                label: '你的音',
                value: _midiName(userMidi),
                subValue: userMidi >= 0
                    ? '${state.lastFrequencyHz.toStringAsFixed(1)} Hz'
                    : '--',
              ),
              _Metric(label: '参考', value: _midiName(refMidi)),
              _Metric(label: '伴奏', value: _midiName(playbackMidi)),
            ],
          ),
          SizedBox(height: ui(8)),
          Row(
            children: [
              _Metric(
                label: '偏差',
                value: cents.isFinite
                    ? '${cents > 0 ? '+' : ''}${cents.round()}c'
                    : '--',
              ),
              _Metric(
                label: '置信',
                value: state.lastFrameConfidence > 0
                    ? state.lastFrameConfidence.toStringAsFixed(2)
                    : '--',
              ),
              _Metric(
                label: '振幅',
                value: amplitude > 0
                    ? amplitude.toStringAsFixed(3)
                    : '--',
              ),
            ],
          ),
          SizedBox(height: ui(6)),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(3),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF3),
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  '链路: ${state.lastSourceLabel}',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: const Color(0xFF4A5568),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              SizedBox(width: ui(6)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(3),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF3),
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  '${state.scoredCount}/${state.hitCount} hit',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: const Color(0xFF4A5568),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.subValue});

  final String label;
  final String value;
  final String? subValue;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(10),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            value,
            style: TextStyle(
              fontSize: ui(14),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'Barlow',
            ),
          ),
          if (subValue != null)
            Text(
              subValue!,
              style: TextStyle(
                fontSize: ui(10),
                color: const Color(0xFF788698),
                fontFamily: 'Inter',
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: ui(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: ui(4), top: ui(4)),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(12),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A5568),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _IntSlider extends StatelessWidget {
  const _IntSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String unit;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final ValueChanged<int> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return _SliderRow(
      label: label,
      valueLabel: '$value$unit',
      hint: hint,
      slider: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions,
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}

class _DoubleSlider extends StatelessWidget {
  const _DoubleSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.decimals = 1,
    this.hint,
  });

  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final int decimals;
  final ValueChanged<double> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return _SliderRow(
      label: label,
      valueLabel: '${value.toStringAsFixed(decimals)}$unit',
      hint: hint,
      slider: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.slider,
    this.hint,
  });

  final String label;
  final String valueLabel;
  final Widget slider;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: ui(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: const Color(0xFF1A1A1A),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: ui(11),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFF1A1A1A),
              inactiveTrackColor: const Color(0xFFD0D5DD),
              thumbColor: const Color(0xFF1A1A1A),
            ),
            child: slider,
          ),
          if (hint != null)
            Padding(
              padding: EdgeInsets.only(bottom: ui(4)),
              child: Text(
                hint!,
                style: TextStyle(
                  fontSize: ui(10),
                  color: const Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoolRow extends StatelessWidget {
  const _BoolRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: const Color(0xFF1A1A1A),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: const Color(0xFF1A1A1A),
              ),
            ],
          ),
          if (hint != null)
            Text(
              hint!,
              style: TextStyle(
                fontSize: ui(10),
                color: const Color(0xFF788698),
                fontFamily: 'PingFang SC',
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onReset, required this.onExport});

  final VoidCallback? onReset;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: Text(
              '复位',
              style: TextStyle(fontSize: ui(12), fontFamily: 'PingFang SC'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFFD0D5DD)),
              padding: EdgeInsets.symmetric(vertical: ui(8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ui(20)),
              ),
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.copy_all_rounded, size: 16),
            label: Text(
              '复制 Dart 源码',
              style: TextStyle(fontSize: ui(12), fontFamily: 'PingFang SC'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: ui(8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ui(20)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
