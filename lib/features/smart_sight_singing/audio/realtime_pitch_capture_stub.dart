import 'realtime_pitch_capture.dart';

class _WebRealtimePitchCapture implements RealtimePitchCapture {
  @override
  bool get isRunning => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<Stream<RealtimePitchEvent>> start() async {
    throw UnsupportedError('Web 暂不支持实时录音音高检测，请在 iPad 上使用。');
  }

  @override
  Future<void> stop() async {}
}

RealtimePitchCapture createPlatformRealtimePitchCapture({
  RealtimePitchCaptureProfile profile = RealtimePitchCaptureProfile.general,
}) =>
    _WebRealtimePitchCapture();
