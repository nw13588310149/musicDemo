import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'pitch_track.dart';
import 'realtime_pitch_capture.dart';

class _IORealtimePitchCapture implements RealtimePitchCapture {
  _IORealtimePitchCapture({required this.profile})
      : _detector = PitchDetector(
          audioSampleRate: _sampleRate.toDouble(),
          bufferSize: profile == RealtimePitchCaptureProfile.sightSinging
              ? 4096
              : 2048,
        ),
        _frameBuffer = Uint8List(
          (profile == RealtimePitchCaptureProfile.sightSinging ? 4096 : 2048) *
              2,
        );

  final RealtimePitchCaptureProfile profile;

  static const int _sampleRate = 44100;

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector;

  StreamSubscription<Uint8List>? _streamSub;
  StreamController<RealtimePitchEvent>? _controller;
  final Uint8List _frameBuffer;
  int _filledBytes = 0;
  bool _running = false;

  bool get _isSightSinging =>
      profile == RealtimePitchCaptureProfile.sightSinging;

  bool get _isVisualOnly =>
      profile == RealtimePitchCaptureProfile.visualOnly;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted || status.isLimited) return true;
    return _recorder.hasPermission();
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted || status.isLimited) return true;
    return _recorder.hasPermission();
  }

  RecordConfig get _recordConfig {
    const iosConfig = IosRecordConfig(
      categoryOptions: [
        IosAudioCategoryOption.allowBluetooth,
        IosAudioCategoryOption.allowBluetoothA2DP,
      ],
    );
    return RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      echoCancel: _isSightSinging,
      noiseSuppress: false,
      iosConfig: iosConfig,
    );
  }

  @override
  Future<Stream<RealtimePitchEvent>> start() async {
    if (_running) {
      throw StateError('RealtimePitchCapture already running');
    }
    var allowed = await hasPermission();
    if (!allowed) {
      allowed = await requestPermission();
    }
    if (!allowed) {
      throw StateError('录音权限被拒绝');
    }

    try {
      switch (profile) {
        case RealtimePitchCaptureProfile.sightSinging:
          await NativePlaybackAudioSession.ensureSightSingingActive();
        case RealtimePitchCaptureProfile.visualOnly:
          await NativePlaybackAudioSession.ensurePlayAndRecordActive();
        case RealtimePitchCaptureProfile.general:
          await NativePlaybackAudioSession.ensureRecordActive();
      }
    } catch (_) {
      // 配置失败不阻断录音本身。
    }

    final pcmStream = await _recorder.startStream(_recordConfig);

    final controller = StreamController<RealtimePitchEvent>(
      onCancel: () async {
        await stop();
      },
    );
    _controller = controller;
    _filledBytes = 0;
    _running = true;

    _streamSub = pcmStream.listen(
      (chunk) => _consumeChunk(chunk, controller),
      onError: (Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      },
      onDone: () async {
        await stop();
      },
      cancelOnError: false,
    );

    return controller.stream;
  }

  void _consumeChunk(Uint8List chunk, StreamController<RealtimePitchEvent> out) {
    var offset = 0;
    while (offset < chunk.length) {
      final need = _frameBuffer.length - _filledBytes;
      final available = chunk.length - offset;
      final take = available < need ? available : need;
      _frameBuffer.setRange(
        _filledBytes,
        _filledBytes + take,
        chunk,
        offset,
      );
      _filledBytes += take;
      offset += take;
      if (_filledBytes == _frameBuffer.length) {
        // 拷贝一份，避免 detector 内部异步访问到下一帧覆写后的数据。
        final frame = Uint8List.fromList(_frameBuffer);
        _filledBytes = 0;
        _emitFrame(frame, out);
      }
    }
  }

  Future<void> _emitFrame(
    Uint8List frame,
    StreamController<RealtimePitchEvent> out,
  ) async {
    if (!_running || out.isClosed) return;

    // 振幅 / RMS 计算。
    final view = ByteData.sublistView(frame);
    var sumSq = 0.0;
    var peak = 0.0;
    final n = frame.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final s = view.getInt16(i * 2, Endian.little).toDouble();
      sumSq += s * s;
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }
    final rms = math.sqrt(sumSq / n);
    final peakNorm = (peak / 32767.0).clamp(0.0, 1.0);
    // 人声 RMS 通常在 300~4000；按 ~900 映射到 0~1，便于 UI 显示「拾音中」。
    final rmsNorm = (rms / 900.0).clamp(0.0, 1.0);
    final amplitude = math.max(peakNorm * 0.55, rmsNorm);

    final silenceThreshold =
        _isSightSinging ? 220.0 : (_isVisualOnly ? 180.0 : 240.0);
    if (rms < silenceThreshold) {
      if (!out.isClosed) {
        out.add(
          RealtimePitchEvent(
            frequencyHz: 0,
            midi: -1,
            confidence: 0,
            amplitude: amplitude,
            pitched: false,
          ),
        );
      }
      return;
    }

    try {
      final result = await _detector.getPitchFromIntBuffer(frame);
      if (!_running || out.isClosed) return;
      final hz = result.pitch;
      final midi = (result.pitched && hz > 0 && hz.isFinite)
          ? PitchUtils.hzToMidi(hz)
          : double.nan;
      final minConfidence = _isSightSinging
          ? 0.70
          : (_isVisualOnly ? 0.68 : 0.72);
      final pitched = result.pitched &&
          result.probability > minConfidence &&
          hz > 70 &&
          hz < 1200 &&
          midi.isFinite;
      out.add(
        RealtimePitchEvent(
          frequencyHz: pitched ? hz : 0,
          midi: pitched ? midi : -1,
          confidence: result.probability,
          amplitude: amplitude,
          pitched: pitched,
        ),
      );
    } catch (_) {
      if (!out.isClosed) out.add(RealtimePitchEvent.empty);
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _streamSub?.cancel();
    _streamSub = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    _filledBytes = 0;
  }
}

RealtimePitchCapture createPlatformRealtimePitchCapture({
  RealtimePitchCaptureProfile profile = RealtimePitchCaptureProfile.general,
}) =>
    _IORealtimePitchCapture(profile: profile);
