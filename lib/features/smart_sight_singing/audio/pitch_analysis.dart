import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'pitch_track.dart';

/// Smart sight-singing offline pitch analysis (flutter_soloud + YIN).
abstract final class SightSingingPitchAnalyzer {
  static const int analysisSampleRate = 22050;
  static const int yinBufferSize = 1024;
  static const int yinHopSize = 512;
  static const int _maxAnalysisSeconds = 600;

  static const String _msgWebNoPath =
      'Web \u7aef\u6682\u4e0d\u652f\u6301\u4ece\u672c\u5730\u8def\u5f84\u5206\u6790\u97f3\u9891\uff0c'
      '\u8bf7\u4f7f\u7528 iPad \u6216\u91cd\u65b0\u9009\u62e9\u6587\u4ef6\u3002';
  static const String _msgReadFailed =
      '\u65e0\u6cd5\u8bfb\u53d6\u97f3\u9891\u6570\u636e\uff0c\u8bf7\u6362\u4e00\u9996\u6b4c\u8bd5\u8bd5\u3002';

  static Future<PitchTrack> analyzeFile(String path) async {
    if (kIsWeb) {
      throw PitchAnalysisException(_msgWebNoPath);
    }
    await _ensureSoLoudReady();
    final maxSamples = _maxAnalysisSeconds * analysisSampleRate;
    final samples = await SoLoud.instance.readSamplesFromFile(
      path,
      maxSamples,
      average: false,
    );
    if (samples.isEmpty) {
      throw PitchAnalysisException(_msgReadFailed);
    }
    return _yinPipelineFromFloat(samples);
  }

  static Future<PitchTrack> analyzeBytes(
    Uint8List bytes, {
    required String formatHint,
  }) async {
    await _ensureSoLoudReady();
    final maxSamples = _maxAnalysisSeconds * analysisSampleRate;
    final samples = await SoLoud.instance.readSamplesFromMem(
      bytes,
      maxSamples,
      average: false,
    );
    if (samples.isEmpty) {
      throw PitchAnalysisException(_msgReadFailed);
    }
    return _yinPipelineFromFloat(samples);
  }

  static Future<void> _ensureSoLoudReady() async {
    await NativePlaybackAudioSession.ensurePlaybackActive();
    final soLoud = SoLoud.instance;
    if (!soLoud.isInitialized) {
      await soLoud.init(
        sampleRate: analysisSampleRate,
        bufferSize: 2048,
        channels: Channels.mono,
      );
    }
  }
}

class PitchAnalysisException implements Exception {
  PitchAnalysisException(this.message);
  final String message;
  @override
  String toString() => 'PitchAnalysisException: $message';
}

Future<PitchTrack> _yinPipelineFromFloat(Float32List floats) async {
  final pcm = _floatToInt16Bytes(floats);
  return _yinPipeline(pcm);
}

Uint8List _floatToInt16Bytes(Float32List floats) {
  final out = ByteData(floats.length * 2);
  for (var i = 0; i < floats.length; i++) {
    final clamped = floats[i].clamp(-1.0, 1.0);
    out.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}

Future<PitchTrack> _yinPipeline(Uint8List pcm) async {
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
        timeMs: timeMs,
        frequencyHz: 0,
        midi: -1,
        confidence: 0,
      ));
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
