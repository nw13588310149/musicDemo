import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'pitch_track.dart';
import 'realtime_pitch_capture.dart';

class _IORealtimePitchCapture implements RealtimePitchCapture {
  _IORealtimePitchCapture();

  static const int _sampleRate = 44100;
  // YIN 缓冲 2048 ≈ 46ms @ 44100Hz，与音乐伴侣调音器保持一致。
  static const int _bufferSize = 2048;

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector = PitchDetector(
    audioSampleRate: _sampleRate.toDouble(),
    bufferSize: _bufferSize,
  );

  StreamSubscription<Uint8List>? _streamSub;
  StreamController<RealtimePitchEvent>? _controller;
  final Uint8List _frameBuffer = Uint8List(_bufferSize * 2);
  int _filledBytes = 0;
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<Stream<RealtimePitchEvent>> start() async {
    if (_running) {
      throw StateError('RealtimePitchCapture already running');
    }
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      throw StateError('录音权限被拒绝');
    }

    // 与录音系统同款：playAndRecord + defaultMode（非调音器 measurement）。
    try {
      await NativePlaybackAudioSession.ensureRecordActive();
    } catch (_) {
      // 配置失败不阻断录音本身。
    }

    final pcmStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

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
    // 0~1 归一化（32767 是 16bit 上限）。
    final amplitude = (rms / 32767.0).clamp(0.0, 1.0);

    if (rms < 350) {
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
      final pitched = result.pitched &&
          result.probability > 0.75 &&
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

RealtimePitchCapture createPlatformRealtimePitchCapture() =>
    _IORealtimePitchCapture();
