import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readRecordedBytes(String source) {
  return File(source).readAsBytes();
}

String createTemporaryRecordingPath() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${Directory.systemTemp.path}${Platform.pathSeparator}music_recording_$timestamp.wav';
}
