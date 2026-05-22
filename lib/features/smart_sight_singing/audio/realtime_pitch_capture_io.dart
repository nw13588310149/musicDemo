import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'pcm_pitch_utils.dart';
import 'pitch_track.dart';
import 'realtime_pitch_capture.dart';

class _IORealtimePitchCapture implements RealtimePitchCapture {
  _IORealtimePitchCapture({required this.profile})
      : _frameBuffer = Uint8List(_bufferSize * 2),
        _detector = PitchDetector(
          audioSampleRate: _sampleRate.toDouble(),
          bufferSize: _bufferSize,
        );

  final RealtimePitchCaptureProfile profile;

  static const int _sampleRate = 44100;
  static const int _bufferSize = 2048;

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector;
  final Uint8List _frameBuffer;

  StreamSubscription<Uint8List>? _streamSub;
  StreamController<RealtimePitchEvent>? _controller;
  int _filledBytes = 0;
  bool _running = false;
  Future<void> _detectChain = Future<void>.value();

  bool get _isSightSinging =>
      profile == RealtimePitchCaptureProfile.sightSinging;

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
    return const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      echoCancel: false,
      noiseSuppress: false,
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
      await NativePlaybackAudioSession.ensureSightSingingCaptureActive();
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
    _detectChain = Future<void>.value();
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
        final frame = Uint8List.fromList(_frameBuffer);
        _filledBytes = 0;
        _enqueueFrame(frame, out);
      }
    }
  }

  void _enqueueFrame(
    Uint8List frame,
    StreamController<RealtimePitchEvent> out,
  ) {
    _detectChain = _detectChain.then((_) => _emitFrame(frame, out));
  }

  Future<void> _emitFrame(
    Uint8List frame,
    StreamController<RealtimePitchEvent> out,
  ) async {
    if (!_running || out.isClosed) return;

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
    final rmsNorm = (rms / 900.0).clamp(0.0, 1.0);
    final amplitude = math.max(peakNorm * 0.55, rmsNorm);

    const silenceThreshold = 200.0;
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
      final floatSamples = pcm16LeToFloatSamples(frame);
      final result = await _detector.getPitchFromFloatBuffer(floatSamples);
      if (!_running || out.isClosed) return;

      final hz = result.pitch;
      final midi = (result.pitched && hz > 0 && hz.isFinite)
          ? PitchUtils.hzToMidi(hz)
          : double.nan;
      // 与离线 pitch_analysis 一致：以 YIN pitched 为准，不过滤 probability。
      final pitched = result.pitched &&
          hz > 65 &&
          hz < 1400 &&
          midi.isFinite &&
          (!_isSightSinging || result.probability > 0.12);
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
    _detectChain = Future<void>.value();
  }
}

RealtimePitchCapture createPlatformRealtimePitchCapture({
  RealtimePitchCaptureProfile profile = RealtimePitchCaptureProfile.general,
}) =>
    _IORealtimePitchCapture(profile: profile);
