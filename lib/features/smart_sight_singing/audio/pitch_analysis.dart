import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

import 'pitch_track.dart';

/// 智能视唱离线音高分析入口（当前暂时停用）。
///
/// 历史：原方案是用 `audio_decoder` 把 MP3 解码为 PCM，再喂入
/// `pitch_detector_dart` 的 YIN 算法生成参考曲线。
///
/// 现状：`audio_decoder 0.8.0`（2026-05 新发版）在 iOS iPad 上引入后导致
/// 应用启动阶段 `GeneratedPluginRegistrant` 注册原生插件时立即闪退。
/// 为了恢复 iPad 主流程稳定性，已在 [`pubspec.yaml`] 中暂时停用 audio_decoder
/// 并隐藏「智能视唱」左侧入口与路由 case。
///
/// 本类保留为占位 stub：所有公开 API 直接抛
/// [`PitchAnalysisException`]，确保未来重新启用时可以原地替换实现而无需改
/// 动调用方。
///
/// 重新启用时的备选方案：
/// 1) 等 `audio_decoder` 升级修复 iOS 启动崩溃后恢复原 implementation；
/// 2) 改用 `flutter_soloud.readSamplesFromFile` 直接读 mono 22050 PCM；
/// 3) 把音高分析挪到服务端，前端只播放 + 拉曲线 JSON。
abstract final class SightSingingPitchAnalyzer {
  static const int analysisSampleRate = 22050;
  static const int yinBufferSize = 1024;
  static const int yinHopSize = 512;

  static Future<PitchTrack> analyzeFile(String path) {
    throw PitchAnalysisException('智能视唱暂未上线，请稍后再试。');
  }

  static Future<PitchTrack> analyzeBytes(
    Uint8List bytes, {
    required String formatHint,
  }) {
    throw PitchAnalysisException('智能视唱暂未上线，请稍后再试。');
  }
}

class PitchAnalysisException implements Exception {
  PitchAnalysisException(this.message);
  final String message;
  @override
  String toString() => 'PitchAnalysisException: $message';
}

// ───────────────────────────────────────────────────────────────────────────
// 以下工具函数保留供未来在恢复实现时直接复用（YIN 切帧 + 5 点中值平滑），
// 当前未被引用，加 `// ignore:` 防止 lint 阻塞 dart analyze。
// ───────────────────────────────────────────────────────────────────────────

// ignore: unused_element
Future<PitchTrack> _yinPipeline(Uint8List wavBytes) async {
  final pcm = _stripWavHeader(wavBytes);
  const sampleRate = SightSingingPitchAnalyzer.analysisSampleRate;
  const bufSize = SightSingingPitchAnalyzer.yinBufferSize;
  const hop = SightSingingPitchAnalyzer.yinHopSize;

  final detector = PitchDetector(
    audioSampleRate: sampleRate.toDouble(),
    bufferSize: bufSize,
  );

  final totalSamples = pcm.length ~/ 2;
  if (totalSamples < bufSize) {
    return const PitchTrack(
      frames: <PitchFrame>[],
      totalMs: 0,
      frameStepMs: 0,
      minMidi: 48,
      maxMidi: 72,
    );
  }

  final totalMs = (totalSamples * 1000) ~/ sampleRate;
  const stepMs = (hop * 1000) ~/ sampleRate;

  final frames = <PitchFrame>[];
  final frameBuf = Uint8List(bufSize * 2);
  final view = ByteData.sublistView(pcm);

  double minMidi = double.infinity;
  double maxMidi = -double.infinity;

  for (var start = 0; start + bufSize <= totalSamples; start += hop) {
    final byteStart = start * 2;
    frameBuf.setRange(0, bufSize * 2, pcm, byteStart);

    var sumSq = 0.0;
    for (var i = 0; i < bufSize; i++) {
      final s = view.getInt16(byteStart + i * 2, Endian.little).toDouble();
      sumSq += s * s;
    }
    final rms = math.sqrt(sumSq / bufSize);
    final timeMs = ((start + bufSize ~/ 2) * 1000) ~/ sampleRate;

    if (rms < 350) {
      frames.add(PitchFrame(
          timeMs: timeMs, frequencyHz: 0, midi: -1, confidence: 0));
      continue;
    }

    final result = await detector.getPitchFromIntBuffer(frameBuf);
    final hz = result.pitch;
    final midi = (result.pitched && hz > 0 && hz.isFinite)
        ? PitchUtils.hzToMidi(hz)
        : double.nan;
    final ok =
        result.pitched && hz > 0 && midi.isFinite && hz > 60 && hz < 1400;

    if (ok) {
      if (midi < minMidi) minMidi = midi;
      if (midi > maxMidi) maxMidi = midi;
    }

    frames.add(PitchFrame(
      timeMs: timeMs,
      frequencyHz: ok ? hz : 0,
      midi: ok ? midi : -1,
      confidence: result.probability,
    ));
  }

  if (!minMidi.isFinite || !maxMidi.isFinite) {
    minMidi = 48;
    maxMidi = 72;
  } else {
    minMidi = (minMidi - 2).clamp(24, 96).toDouble();
    maxMidi = (maxMidi + 2).clamp(minMidi + 6, 100).toDouble();
  }

  return PitchTrack(
    frames: _medianSmooth(frames),
    totalMs: totalMs,
    frameStepMs: stepMs > 0 ? stepMs : 1,
    minMidi: minMidi,
    maxMidi: maxMidi,
  );
}

// ignore: unused_element
List<PitchFrame> _medianSmooth(List<PitchFrame> frames) {
  if (frames.length < 5) return frames;
  final result = List<PitchFrame>.from(frames, growable: false);
  final window = <double>[];
  for (var i = 0; i < frames.length; i++) {
    if (!frames[i].pitched) continue;
    window.clear();
    for (var k = -2; k <= 2; k++) {
      final j = i + k;
      if (j < 0 || j >= frames.length) continue;
      if (frames[j].pitched) window.add(frames[j].midi);
    }
    if (window.length < 3) continue;
    window.sort();
    final med = window[window.length ~/ 2];
    if ((med - frames[i].midi).abs() > 0.6) {
      result[i] = PitchFrame(
        timeMs: frames[i].timeMs,
        frequencyHz: PitchUtils.midiToHz(med),
        midi: med,
        confidence: frames[i].confidence,
      );
    }
  }
  return result;
}

// ignore: unused_element
Uint8List _stripWavHeader(Uint8List bytes) {
  if (bytes.length < 44) return bytes;
  final limit = math.min(bytes.length, 256);
  for (var i = 0; i + 8 <= limit; i++) {
    if (bytes[i] == 0x64 &&
        bytes[i + 1] == 0x61 &&
        bytes[i + 2] == 0x74 &&
        bytes[i + 3] == 0x61) {
      return Uint8List.sublistView(bytes, i + 8);
    }
  }
  return bytes;
}

// 保留对 [kIsWeb] / [debugPrint] 的间接依赖位（防止未来恢复时漏掉 import）。
// ignore: unused_element
void _ignoreUnusedImports() {
  // ignore: avoid_print
  if (kIsWeb) debugPrint('sight singing pitch analyzer stub');
}
