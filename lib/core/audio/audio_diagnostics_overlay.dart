import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/music_companion/audio/music_companion_audio_engine.dart';
import 'app_audio_service.dart';
import 'native_playback_audio_session.dart';

/// 屏幕音频诊断面板（临时排障用）。
///
/// 因为真机走 Codemagic/TestFlight Release 包、拿不到控制台日志，这个面板把
/// 「会话是否激活 / 类别 / 原生引擎是否在跑 / 走原生还是 just_audio 回退 /
/// 解码进度 / 最后报错」直接显示在屏幕上，方便用户截图反馈定位。
///
/// 用法：包在 [MaterialApp.builder] 的 child 外层即可，全页面右下角出现一个
/// 小圆点；点开展开面板。排障完成后整块删除即可。
class AudioDiagnosticsOverlay extends StatefulWidget {
  const AudioDiagnosticsOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AudioDiagnosticsOverlay> createState() =>
      _AudioDiagnosticsOverlayState();
}

class _AudioDiagnosticsOverlayState extends State<AudioDiagnosticsOverlay> {
  bool _expanded = false;
  Timer? _timer;
  Map<String, Object?> _snapshot = const <String, Object?>{};
  String _actionLog = '';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setExpanded(bool value) {
    setState(() => _expanded = value);
    _timer?.cancel();
    if (value) {
      _refresh();
      _timer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _refresh(),
      );
    }
  }

  Future<void> _refresh() async {
    final result = <String, Object?>{
      'session.profile': NativePlaybackAudioSession.currentProfileLabel,
      'session.activated': NativePlaybackAudioSession.isActivated,
      'session.lastError': NativePlaybackAudioSession.lastError ?? '-',
      'pianoReady': AppAudioService.isNativePianoReady,
    };
    try {
      final d = await AppAudioService.diagnostics().timeout(
        const Duration(seconds: 4),
      );
      result.addAll(d);
    } catch (e) {
      result['diagnostics.error'] = '$e';
    }
    if (!mounted) return;
    setState(() => _snapshot = result);
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    setState(() => _actionLog = '$label …');
    try {
      await action();
      if (!mounted) return;
      setState(() => _actionLog = '$label ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLog = '$label ✗ $e');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 12,
          bottom: 120,
          child: _expanded ? _buildPanel() : _buildDot(),
        ),
      ],
    );
  }

  Widget _buildDot() {
    return GestureDetector(
      onTap: () => _setExpanded(true),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.tealAccent, width: 2),
        ),
        alignment: Alignment.center,
        child: const Text(
          'A?',
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final entries = _snapshot.entries.toList();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 460),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.tealAccent, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '音频诊断',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _setExpanded(false),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in entries) _line(e.key, '${e.value}'),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _btn('刷新', _refresh),
                _btn('激活播放会话', AppAudioService.reconcilePlaybackSession),
                _btn('初始化钢琴', () async {
                  final engine = MusicCompanionAudioEngine.debugLastInstance;
                  await engine?.ensurePianoInitialized();
                }),
                _btn('播放测试音C4', () async {
                  final engine = MusicCompanionAudioEngine.debugLastInstance;
                  await engine?.debugPlayTestNote();
                }),
              ],
            ),
            if (_actionLog.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _actionLog,
                style: const TextStyle(color: Colors.amber, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String key, String value) {
    final moviePlaybackDrift = key == 'native_sessionMode' &&
        value.contains('MoviePlayback');
    final bad =
        moviePlaybackDrift ||
        (value == 'false' &&
            (key.contains('Running') ||
                key.contains('activated') ||
                key.contains('Built'))) ||
        (key.toLowerCase().contains('error') && value != '-' && value != 'null');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              key,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: bad ? Colors.redAccent : Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, Future<void> Function() action) {
    return GestureDetector(
      onTap: () => _runAction(label, action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.tealAccent, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
        ),
      ),
    );
  }
}
